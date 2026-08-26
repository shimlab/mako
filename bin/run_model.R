#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    library(tidyverse)
    library(duckdb)
    library(optparse)
    library(nanoparquet)
    library(glmmTMB)
    library(DSS)
})


# ==============================
# Models
# ==============================

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
        p_value = coefs[2, "Pr(>|z|)"],
        drop = FALSE
    )
    
    return(result)
}

beta_binomial_model <- function(df) {
    agg_df <- binarize(df)

    model <- glmmTMB(cbind(successes, failures) ~ group_name,
        data = agg_df,
        family = glmmTMB::betabinomial(link = "logit")
    )

    disp_val <- summary(model)$sigma
    if (disp_val > 1e5) {
        stop(sprintf("Dispersion parameter too large: %f", disp_val))
    }

    coefs <- summary(model)$coefficients$cond

    result <- data.frame(
        estimate = coefs[2, "Estimate"],
        std_err = coefs[2, "Std. Error"],
        test_statistic = coefs[2, "z value"],
        p_value = coefs[2, "Pr(>|z|)"],
        drop = FALSE
    )
    
    return(result)
}

dss_model <- function(counts_df, threads = NULL) {
    if (is.null(threads) || is.na(threads) || threads <= 0L) {
        stop("A valid positive integer for 'threads' must be specified for dss_model.")
    }
    
    sample_info <- unique(counts_df[, c("sample_name", "group_name")])
    
    groups <- unique(sample_info$group_name)
    if (length(groups) < 2) {
        stop("Only one group present; cannot run two-group differential test.")
    }
    control_samples <- sample_info$sample_name[sample_info$group_name == groups[1]]
    treated_samples <- sample_info$sample_name[sample_info$group_name == groups[2]]
    all_samples     <- c(control_samples, treated_samples)
    
    # Filter away trivial non-differentially modified sites
    # (sites with 0 modified reads or 0 unmodified reads across all samples)
    site_totals <- stats::aggregate(cbind(successes, total) ~ site_idx, data = counts_df, FUN = sum)
    is_trivial  <- (site_totals$successes == 0L) | (site_totals$successes == site_totals$total)
    trivial_site_ids     <- site_totals$site_idx[is_trivial]
    non_trivial_site_ids <- site_totals$site_idx[!is_trivial]
    
    # Trivial sites output (drop = TRUE, NA statistics)
    trivial_results <- if (length(trivial_site_ids) > 0) {
        data.frame(
            site_idx       = trivial_site_ids,
            estimate       = NA_real_,
            std_err        = NA_real_,
            test_statistic = NA_real_,
            p_value        = NA_real_,
            drop           = TRUE
        )
    } else {
        data.frame(
            site_idx       = integer(0),
            estimate       = numeric(0),
            std_err        = numeric(0),
            test_statistic = numeric(0),
            p_value        = numeric(0),
            drop           = logical(0)
        )
    }
    
    if (length(non_trivial_site_ids) == 0) {
        return(trivial_results[order(trivial_results$site_idx), ])
    }
    
    # Process only non-trivial candidate sites with DSS
    valid_counts_df <- counts_df[counts_df$site_idx %in% non_trivial_site_ids, ]
    
    bsseq_list <- lapply(all_samples, function(sample) {
        sample_df <- valid_counts_df[valid_counts_df$sample_name == sample, ]
        sample_df <- sample_df[order(sample_df$site_idx), ]
        data.frame(
            chr = "chr1",
            pos = sample_df$site_idx,
            N   = as.integer(sample_df$total),
            X   = as.integer(sample_df$successes)
        )
    })
    names(bsseq_list) <- all_samples
    
    # Adaptive equal.disp:
    # If both groups have replicates (>= 2), allow unequal dispersions (DSS default);
    # if either group has only 1 sample, assume equal dispersion across groups.
    use_equal_disp <- (length(control_samples) < 2 || length(treated_samples) < 2)
    
    n_cores <- as.integer(threads)
    cat(sprintf("Running DSS DMLtest with %d core(s)...\n", n_cores))
    
    # Build BSseq object
    bsseq_data <- DSS::makeBSseqData(bsseq_list, sampleNames = all_samples)
    
    # Run DSS
    dml_results <- DSS::DMLtest(
        bsseq_data,
        group1     = control_samples,
        group2     = treated_samples,
        smoothing  = FALSE,
        equal.disp = use_equal_disp,
        ncores     = n_cores
    )
    
    valid_results <- data.frame(
        site_idx       = dml_results$pos,
        estimate       = dml_results$diff,
        std_err        = dml_results$diff.se,
        test_statistic = dml_results$stat,
        p_value        = dml_results$pval,
        drop           = is.na(dml_results$pval)
    )
    
    # Combine valid test results with dropped trivial sites
    result_df <- rbind(valid_results, trivial_results)
    result_df <- result_df[order(result_df$site_idx), ]
    rownames(result_df) <- NULL
    
    return(result_df)
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

binarize <- function(df) {
    threshold = args$modification_threshold

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
        SELECT rname, transcript_position, chr, chr_position, transcript_id FROM sites
        WHERE selected = TRUE
        ORDER BY rname, transcript_position
        OFFSET ?
        LIMIT ?
        ",
        list(start, end - start + 1)
    )


    # get corresponding reads
    # we don't need chr/transcript_id since we only join on rname and transcript_position later on
    df <- dbGetQuery(
        con,
        "
        SELECT *
        FROM all_sites.reads
        SEMI JOIN (
            SELECT rname, transcript_position FROM sites
            WHERE selected = TRUE
            ORDER BY rname, transcript_position
            OFFSET ?
            LIMIT ?
        ) USING (rname, transcript_position)
        ",
        list(start, end - start + 1),
    )

    cat("  ", nrow(df), "rows\n")

    dbDisconnect(con)

    reads <- df %>%
      mutate(
        group_name = factor(group_name),
        logit = logit(probability_modified)
      )

    return(list(sites=sites, reads=reads))
}

fetch_dss_counts <- function(start, end, sites_db, reads_db, threshold) {
    con <- dbConnect(duckdb(), dbdir = sites_db, read_only = TRUE)
    dbExecute(con, sprintf("ATTACH '%s' AS all_sites (READONLY);", reads_db))

    cat("  Fetching sites metadata...\n")
    sites <- dbGetQuery(
        con,
        "
        SELECT 
            row_number() OVER (ORDER BY rname, transcript_position) AS site_idx,
            rname, 
            transcript_position, 
            chr, 
            chr_position, 
            transcript_id 
        FROM sites
        WHERE selected = TRUE
        ORDER BY rname, transcript_position
        OFFSET ?
        LIMIT ?
        ",
        list(start, end - start + 1)
    )

    cat(sprintf("  Aggregating read counts for %d sites in DuckDB SQL...\n", nrow(sites)))
    counts <- dbGetQuery(
        con,
        "
        WITH batch_sites AS (
            SELECT 
                row_number() OVER (ORDER BY rname, transcript_position) AS site_idx,
                rname, 
                transcript_position
            FROM sites
            WHERE selected = TRUE
            ORDER BY rname, transcript_position
            OFFSET ?
            LIMIT ?
        )
        SELECT 
            s.site_idx,
            r.sample_name,
            r.group_name,
            SUM(CASE WHEN r.probability_modified >= ? THEN 1 ELSE 0 END) AS successes,
            COUNT(*) AS total
        FROM batch_sites s
        JOIN all_sites.reads r ON r.rname = s.rname AND r.transcript_position = s.transcript_position
        WHERE r.ignored = FALSE
        GROUP BY s.site_idx, r.sample_name, r.group_name
        ORDER BY s.site_idx, r.sample_name
        ",
        list(start, end - start + 1, threshold)
    )

    dbDisconnect(con)
    return(list(sites = sites, counts = counts))
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
        } else if (dispersion > 1.0) {
            # run beta-binomial with binomial fallback
            output_df <- run_model(df, "beta_binomial")
            if (isTRUE(output_df$error)) {
                output_df <- run_model(df, "binomial")
            }
        } else {
            # could not determine model - produce error
            output_df <- data.frame(
                estimate = NA_real_,
                std_err = NA_real_,
                test_statistic = NA_real_,
                p_value = NA_real_,
                drop = FALSE,
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
    # if the reads are ALL modified or ALL unmodified, we can't fit a model - return NA results and drop the site
    threshold = args$modification_threshold
    if (sum(df$probability_modified >= threshold) == 0 || sum(df$probability_modified < threshold) == 0) {
        return(data.frame(
            estimate = NA_real_,
            std_err = NA_real_,
            test_statistic = NA_real_,
            p_value = NA_real_,
            drop = TRUE,
            model_type = NA_character_,
            error = NA,
            error_message = NA_character_
        ))
    }

    model_func <- switch(model_type,
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
                drop = FALSE,
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
        make_option(c("--min-reads-per-sample"),
            type = "integer", default = 5L,
            help = "Minimum reads per sample required to include a site [default=%default]", metavar = "number"
        ),
        make_option(c("--modification-threshold"),
            type = "double", default = 0.5,
            help = "Threshold for binarizing modification status (for binomial models) [default=%default]", metavar = "number"
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
            type = "character", default = "dss",
            help = "Statistical model to use: dss (default), adaptive_binomial, binomial, or beta_binomial [default=%default]", metavar = "character"
        ),
        make_option(c("--gtf"),
            type = "character", default = NULL,
            help = "Path to the GTF file for transcriptome to genome mapping", metavar = "character"
        ),
        make_option(c("--threads"),
            type = "integer", default = NULL,
            help = "Number of threads/CPUs to use for parallel processing", metavar = "number"
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

    if (is.null(args$threads) || is.na(args$threads) || args$threads <= 0L) {
        print_help(parser)
        stop("A valid positive integer for --threads is required.")
    }

    cat("Parameters:\n")
    cat("  Reads database:", args$reads_database, "\n")
    cat("  Min reads per sample:", args$min_reads_per_sample, "\n")
    cat("  Modification threshold:", args$modification_threshold, "\n")
    cat("  Start index:", args$start, "\n")
    cat("  End index:", args$end, "\n")
    cat("  Model:", args$model, "\n")
    cat("  Threads:", args$threads, "\n")
    cat("  Output file:", args$output, "\n\n")
    cat("  GTF file:", args$gtf, "\n\n")

    return(args)
}

# ==============================
# Main script execution
# ==============================

# Only run main script if this file is executed directly (not sourced)
args <- get_args()


# fetch all sample names once before the loop
con_init <- dbConnect(duckdb(), dbdir = args$reads_database, read_only = TRUE)
all_sample_names <- dbGetQuery(con_init, "SELECT DISTINCT sample_name FROM reads")$sample_name
dbDisconnect(con_init)

# preallocate
n_rows <- args$end - args$start + 1
output_df <- data.frame(
    transcript_id = rep(NA_character_, n_rows),
    transcript_position = integer(n_rows),
    rname = rep(NA_character_, n_rows),
    chr = rep(NA_character_, n_rows),
    chr_position = integer(n_rows),
    estimate = numeric(n_rows),
    std_err = numeric(n_rows),
    test_statistic = numeric(n_rows),
    p_value = numeric(n_rows),
    drop = logical(n_rows),
    model_type = rep(NA_character_, n_rows),
    error = logical(n_rows),
    error_message = rep(NA_character_, n_rows)
)


start_time <- Sys.time()

if (args$model == "dss") {
    cat(sprintf("Processing batch (all %d sites) with DSS...\n", n_rows))
    
    # Fetch sites and aggregated sample counts directly from DuckDB SQL
    dss_data <- fetch_dss_counts(args$start, args$end, args$sites_database, args$reads_database, args$modification_threshold)
    
    if (nrow(dss_data$sites) > 0) {
        # Run DSS on all sites in batch
        dss_results <- dss_model(dss_data$counts, threads = args$threads)
        
        # Explicit fail-safe join by site_idx
        matched_output <- dss_data$sites %>%
            dplyr::left_join(dss_results, by = "site_idx")
        
        # Populate output_df directly
        output_df$transcript_id       <- matched_output$transcript_id
        output_df$transcript_position <- matched_output$transcript_position
        output_df$rname               <- matched_output$rname
        output_df$chr                 <- matched_output$chr
        output_df$chr_position        <- matched_output$chr_position
        output_df$estimate            <- matched_output$estimate
        output_df$std_err             <- matched_output$std_err
        output_df$test_statistic      <- matched_output$test_statistic
        output_df$p_value             <- matched_output$p_value
        output_df$drop                <- ifelse(is.na(matched_output$drop), TRUE, matched_output$drop)
        output_df$model_type          <- "dss"
        output_df$error               <- FALSE
        output_df$error_message       <- NA_character_
    }
} else {
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
}

# write to Parquet
write_parquet(output_df, args$output)

end_time <- Sys.time()
time_taken <- end_time - start_time

cat("\nProcessing completed in", format(time_taken), "\n")
cat("Results written to ", args$output, "...\n")
cat("Analysis complete\n")
