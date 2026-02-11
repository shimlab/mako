
suppressPackageStartupMessages({
    library(tidyverse)
    library(duckdb)
    library(optparse)
    library(nlme)
    library(aod)
    library(nanoparquet)
    library(GenomicFeatures)
    library(txdbmaker)
})

options(error = traceback)


# ==============================
# Models
# ==============================

# homoscedastic Gaussian model
homo_norm_model <- function(df) {
    model <- lm(logit ~ group_name, data = df)
    coefs <- summary(model)$coefficients

    result <- data.frame(
        estimate = coefs[2, "Estimate"],
        std_err = coefs[2, "Std. Error"],
        test_statistic = coefs[2, "t value"],
        p_value = coefs[2, "Pr(>|t|)"]
    )
    
    return(result)
}

hetero_norm_model <- function(df) {
    model <- gls(
        logit ~ group_name,
        data = df,
        weights = varIdent(form = ~ 1 | sample_name), method = "ML"
    )

    coefs <- summary(model)$tTable

    result <- data.frame(
        estimate = coefs[2, "Value"],
        std_err = coefs[2, "Std.Error"],
        test_statistic = coefs[2, "t-value"],
        p_value = coefs[2, "p-value"]
    )
    
    return(result)
}

binomial_model <- function(df) {
    agg_df <- binarize(df)

    model <- glm(cbind(successes, failures) ~ group_name,
        data = agg_df,
        family = binomial
    )

    coefs <- summary(model)$coefficients

    result <- data.frame(
        estimate = coefs[2, "Estimate"],
        std_err = coefs[2, "Std. Error"],
        test_statistic = coefs[2, "z value"],
        p_value = coefs[2, "Pr(>|z|)"]
    )
    
    return(result)
}

beta_binomial_model <- function(df) {
    agg_df <- binarize(df)

    model <- betabin(cbind(successes, failures) ~ group_name, ~1,
        data = agg_df
    )

    coefs <- summary(model)@Coef

    result <- data.frame(
        estimate = coefs[2, "Estimate"],
        std_err = coefs[2, "Std. Error"],
        test_statistic = coefs[2, "z value"],
        p_value = coefs[2, "Pr(> |z|)"]
    )
    
    return(result)
}


# ==============================
# Utility functions
# ==============================

get_dispersion <- function(df) {
    agg_df <- binarize(df)
    
    # Fit quasi-binomial model
    fit <- glm(cbind(successes, failures) ~ group_name,
            data = agg_df,
            family = quasibinomial(link = "logit"))

    # Extract dispersion parameter
    dispersion <- summary(fit)$dispersion

    return(dispersion)
}

logit <- function(p) {
    eps <- 1e-10
    log((p + eps) / (1 - p + eps))
}

binarize <- function(df, threshold=0.5) {
    # compute pseudocounts for successes and failures
    binarized_df <- df %>%
        group_by(sample_name, group_name) %>%
        summarise(
            successes = sum(probability_modified >= threshold) + 1,
            failures = sum(probability_modified < threshold) + 1,
            .groups = "keep"
        ) %>%
        ungroup()
    
    return(binarized_df)
}

# ==============================
# Data loading
# ==============================

fetch_dataframe <- function(start, end, sites_db, reads_db) {
    con <- dbConnect(duckdb(), dbdir = sites_db, read_only = TRUE)
    dbExecute(con, sprintf("ATTACH '%s' AS all_sites (READONLY);", reads_db))

    # get list of sites
    sites <- dbGetQuery(
        con,
        "
        SELECT rname, transcript_position FROM selected_sites
        ORDER BY rname, transcript_position
        OFFSET ?
        LIMIT ?
        ",
        list(start, end - start + 1)
    )

    sites <- map_to_genome(sites)

    # get corresponding reads
    df <- dbGetQuery(
        con,
        "
        SELECT *
        FROM all_sites.reads
        SEMI JOIN (
            SELECT * FROM selected_sites
            ORDER BY rname, transcript_position
            OFFSET ?
            LIMIT ?
        )
        USING (rname, transcript_position)
        ",
        list(start, end - start + 1)
    )
    
    cat("  ", nrow(df), "rows\n")

    dbDisconnect(con)

    reads <- df %>%
      mutate(
        rname,
        transcript_position,
        sample_name,
        probability_modified,
        ignored,
        group_name = factor(group_name),
        logit = logit(probability_modified),
        .keep = "none"
      )

    return(list(sites=sites, reads=reads))
}


# =============================
# Transcriptome -> genome mapping
# =============================

# Build once and store globally
EXONS_DB <- NULL

init_exons_db <- function(gtf_file) {
  txdb <- txdbmaker::makeTxDbFromGFF(gtf_file)
#   EXONS_DB <<- exonsBy(txdb, by = "tx", use.names = TRUE)
  EXONS_DB <<- exonsBy(txdb, by = c("tx", "gene"), use.names=TRUE)
}

map_to_genome <- function(df) {
  if (is.null(EXONS_DB)) {
    stop("EXONS_DB not initialized. Run init_exons_db() first.")
  }

  # extract the transcript ID from the rname; typically, this is on the whitespace or pipe:
  # GENCODE: ENST00000832824.1|ENSG00000290825.2|-|-|DDX11L16-260|DDX11L16|1379|lncRNA|
  df$transcript_id = str_split_i(df$rname, "[| ]", 1) 
  
  # Create GRanges from transcript coordinates (convert 0-based to 1-based)
  tx_coords <- GRanges(
    seqnames = df$transcript_id,
    ranges = IRanges(start = df$transcript_position + 1, 
                     end = df$transcript_position + 1)
  )

  print(tx_coords)
  print(EXONS_DB)

  # Map to genomic coordinates
  genomic_coords <- mapFromTranscripts(tx_coords, EXONS_DB)

  # Initialize columns with NA
  df$chr <- NA_character_
  df$chr_position <- NA_integer_
  
  # Fill in mapped positions
  mapped_indices <- mcols(genomic_coords)$xHits
  df$chr[mapped_indices] <- as.character(seqnames(genomic_coords))
  df$chr_position[mapped_indices] <- start(genomic_coords) - 1 # Convert back to 0-based
  
  return(df)
}

# ==============================
# Model application
# ==============================

process_modification_site <- function(df, model_type="none") {
    if (model_type == "adaptive_binomial") {
        dispersion <- get_dispersion(df)
        if (dispersion <= 1.0) {
            # run binomial model
            output_df <- run_model(df, "binomial")
        } else if (dispersion < 1.5) {
            # run beta-binomial with binomial fallback
            output_df <- run_model(df, "beta_binomial")
            if (output_df$error) {
                output_df <- run_model(df, "binomial")
            }
        } else if (dispersion >= 1.5) {
            # run beta-binomial model
            output_df <- run_model(df, "beta_binomial")
        } else {
            # could not determine model - produce error
            output_df <- data.frame(
                estimate = NA_real_,
                std_err = NA_real_,
                test_statistic = NA_real_,
                p_value = NA_real_,
                model_type = "none",
                error = TRUE,
                error_message = sprintf("Could not determine model for dispersion: %f", dispersion)
            )
        }
    } else {
        output_df <- run_model(df, model_type)
    }

    return(output_df)
}

# Function to apply statistical model to each site
run_model <- function(df, model_type="none") {
    model_func <- switch(model_type,
        homo_norm = homo_norm_model,
        hetero_norm = hetero_norm_model,
        binomial = binomial_model,
        beta_binomial = beta_binomial_model,
        stop("Unknown model type: ", model_type)
    )

    result <- tryCatch(
        {
            # Check if we have both treatment groups
            if (length(unique(df$group_name)) < 2) {
                stop("Only one level in group_name; cannot fit model.")
            }

            # Select model based on model_type

            result_df <- model_func(df)

            if (sum(is.na(result_df))) {
                stop("Model returned NA values")
            }

            result_df$model_type <- model_type
            result_df$error <- FALSE
            result_df$error_message <- NA_character_

            return(result_df)
        },
        error = function(e) {
            # Return default result on error
            data.frame(
                estimate = NA_real_,
                std_err = NA_real_,
                test_statistic = NA_real_,
                p_value = NA_real_,
                model_type = model_type,
                error = TRUE,
                error_message = paste(
                    conditionMessage(e),
                    "\nCall:",
                    paste(deparse(conditionCall(e)), collapse = ""),
                    "\nStack:",
                    paste(capture.output(sys.calls()), collapse = "\n")
                )
            )
        }
    )

    return(result)
}

# ==============================
# CLI parameter parsing and help
# ==============================

# Parse command line arguments
get_args <- function() {
    option_list <- list(
        make_option(c("--sites-database"),
            type = "character", default = NULL,
            help = "Path to the sites DuckDB database", metavar = "character"
        ),
        make_option(c("--reads-database"),
            type = "character", default = NULL,
            help = "Path to the reads DuckDB database", metavar = "character"
        ),
        make_option(c("--start"),
            type = "integer",
            help = "Start index for data processing [default=%default]", metavar = "number"
        ),
        make_option(c("--end"),
            type = "integer",
            help = "End index for data processing [default=%default]", metavar = "number"
        ),
        make_option(c("--output"),
            type = "character", default = "model_output.tsv",
            help = "Output TSV filename [default=%default]", metavar = "character"
        ),
        make_option(c("--model"),
            type = "character",
            help = "Statistical model to use: homo_norm, hetero_norm, binomial, or beta_binomial [default=%default]", metavar = "character"
        ),
        make_option(c("--gtf"),
            type = "character", default = NULL,
            help = "Path to the GTF file for transcriptome to genome mapping", metavar = "character"
        )
    )

    parser <- OptionParser(option_list = option_list, description = "Run linear model analysis on RNA modification data")
    args <- parse_args(parser, convert_hyphens_to_underscores = TRUE)

    # Validate required arguments
    if (!file.exists(args$sites_database) | !file.exists(args$reads_database)) {
        print_help(parser)
        stop("Sites database file path is required (--sites-database) and reads database file path is required (--reads-database)")
    }

    if (args$start < 0 || args$end <= args$start) {
        stop("Invalid start/end indices. Start must be >= 0 and end must be > start")
    }

    cat("Parameters:\n")
    cat("  Sites database:", args$sites_database, "\n")
    cat("  Reads database:", args$reads_database, "\n")
    cat("  Start index:", args$start, "\n")
    cat("  End index:", args$end, "\n")
    cat("  Model:", args$model, "\n")
    cat("  Output file:", args$output, "\n\n")
    cat("  GTF file:", args$gtf, "\n\n")

    return(args)
}

# ==============================
# Main script execution
# ==============================

# Only run main script if this file is executed directly (not sourced)
args <- get_args()

init_exons_db(args$gtf)

# preallocate
n_rows <- args$end - args$start + 1
output_df <- data.frame(
    transcript_id = rep(NA_character_, n_rows),
    transcript_position = integer(n_rows),
    rname = rep(NA_character_, n_rows),
    chr = rep(NA_character_, n_rows),
    chr_position = integer(n_rows),
    model_type = rep(NA_character_, n_rows),
    estimate = numeric(n_rows),
    std_err = numeric(n_rows),
    test_statistic = numeric(n_rows),
    p_value = numeric(n_rows),
    error = logical(n_rows),
    error_message = rep(NA_character_, n_rows)
)


start_time <- Sys.time()

INTERVAL <- 512

# process in batches, since batched database access is much faster than single-row
for (offset in seq(args$start, args$end - 1, by = INTERVAL)) {
    start <- offset
    end <- min(offset + INTERVAL - 1, args$end)

    cat("Processing rows", start, "to", end, "...\n")

    batch <- fetch_dataframe(start, end, args$sites_database, args$reads_database)

    for (i in seq_len(nrow(batch$sites))) {
        site_tx_id <- batch$sites$transcript_id[i]
        site_tx_pos <- batch$sites$transcript_position[i]
        site_rname <- batch$sites$rname[i]
        site_chr <- batch$sites$chr[i]
        site_chr_pos <- batch$sites$chr_position[i]

        site_reads <- batch$reads %>%
            filter(
                rname == site_rname,
                transcript_position == site_tx_pos,
                ignored == FALSE
            )

        site_df <- process_modification_site(site_reads, args$model)

        # add metadata to the site
        site_df$transcript_id <- site_tx_id
        site_df$transcript_position <- site_tx_pos
        site_df$rname <- site_rname
        site_df$chr <- site_chr
        site_df$chr_position <- site_chr_pos

        if (!(is.na(output_df$model_type[offset - args$start + i]))) {
            stop("Model type not recorded for site ", site_tx_id, ":", site_tx_pos)
        }

        output_df[offset - args$start + i, ] <- site_df[, names(output_df)]
    }
}

# write to Parquet
write_parquet(output_df, args$output)

end_time <- Sys.time()
time_taken <- end_time - start_time

cat("\nProcessing completed in", format(time_taken), "\n")
cat("Results written to ", args$output, "...\n")
cat("Analysis complete\n")
