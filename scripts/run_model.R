
suppressPackageStartupMessages({
    library(tidyverse)
    library(duckdb)
    library(optparse)
    library(nlme)
    library(aod)
    library(nanoparquet)
})


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
        t_value = coefs[2, "t value"],
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
        t_value = coefs[2, "t-value"],
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
        t_value = coefs[2, "z value"],
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
        t_value = coefs[2, "z value"],
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
    binarized_df <- df %>%
        group_by(sample_name, group_name) %>%
        summarise(
            successes = sum(probability_modified >= threshold),
            failures = sum(probability_modified < threshold),
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
        SELECT transcript_id, transcript_position FROM selected_sites
        ORDER BY transcript_id, transcript_position
        OFFSET ?
        LIMIT ?
        ",
        list(start, end - start + 1)
    )

    # get corresponding reads
    df <- dbGetQuery(
        con,
        "
        SELECT *
        FROM all_sites.reads
        SEMI JOIN (
            SELECT * FROM selected_sites
            ORDER BY transcript_id, transcript_position
            OFFSET ?
            LIMIT ?
        )
        USING (transcript_id, transcript_position)
        ",
        list(start, end - start + 1)
    )
    
    cat("  ", nrow(df), "rows\n")

    dbDisconnect(con)

    reads <- df %>%
      mutate(
        transcript_id,
        transcript_position,
        sample_name,
        probability_modified,
        ignored,
        group_name = factor(group_name),
        logit = logit(probability_modified),
        .keep = "none"
      )

    return(list(sites=sites, reads=reads))
    
    # df_nested <- df %>%
    #   mutate(
    #     transcript_id,
    #     transcript_position,
    #     sample_name,
    #     probability_modified,
    #     group_name = factor(group_name),
    #     logit = logit(probability_modified),
    #     .keep = "none"
    #   ) %>%
    #   nest(.by = c(transcript_id, transcript_position))
    
    # cat("; ", nrow(df_nested), "groups\n")
    # return(df_nested)
}



# ==============================
# Model application
# ==============================

process_modification_site <- function(transcript_id, transcript_position, df, model_type="none") {
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
                t_value = NA_real_,
                p_value = NA_real_,
                model_type = "none",
                error = TRUE,
                error_message = sprintf("Could not determine model for dispersion: %f", dispersion)
            )
        }
    } else {
        output_df <- run_model(df, model_type)
    }

    output_df$transcript_id <- transcript_id
    output_df$transcript_position <- transcript_position

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
                t_value = NA_real_,
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
    cat("  Database:", args$db, "\n")
    cat("  Start index:", args$start, "\n")
    cat("  End index:", args$end, "\n")
    cat("  Model:", args$model, "\n")
    cat("  Output file:", args$output, "\n\n")

    return(args)
}

# ==============================
# Main script execution
# ==============================

# Only run main script if this file is executed directly (not sourced)
args <- get_args()

# preallocate
n_rows <- args$end - args$start + 1
output_df <- data.frame(
    transcript_id = integer(n_rows),
    transcript_position = integer(n_rows),
    model_type = rep(NA_character_, n_rows),
    estimate = numeric(n_rows),
    std_err = numeric(n_rows),
    t_value = numeric(n_rows),
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

        site_reads <- batch$reads %>%
            filter(
                transcript_id == site_tx_id,
                transcript_position == site_tx_pos,
                ignored == FALSE
            )

        site_df <- process_modification_site(
            site_tx_id,
            site_tx_pos,
            site_reads,
            args$model
        )

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
