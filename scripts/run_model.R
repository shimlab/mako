# Linear Model MVP - Simplified version of run_models_original.R
# Runs only the linear model: lm(logit ~ trtGrp, data = subset_data)

suppressPackageStartupMessages({
    library(tidyverse)
    library(duckdb)
    library(optparse)
    library(nlme)
    library(aod)
})


# ==============================
# Models
# ==============================

# homoscedastic Gaussian model
homo_norm_model <- function(transcript_id, transcript_position, df) {
    model <- lm(logit ~ group_name, data = df)
    coefs <- summary(model)$coefficients

    result <- data.frame(
        transcript_id = transcript_id,
        transcript_position = transcript_position,
        estimate = coefs[2, "Estimate"],
        std_err = coefs[2, "Std. Error"],
        t_value = coefs[2, "t value"],
        p_value = coefs[2, "Pr(>|t|)"],
        model_error = NA_character_
    )
    
    return(result)
}

hetero_norm_model <- function(transcript_id, transcript_position, df) {
    model <- gls(
        logit ~ group_name,
        data = df,
        weights = varIdent(form = ~ 1 | sample_name), method = "ML"
    )

    coefs <- summary(model)$tTable

    result <- data.frame(
        transcript_id = transcript_id,
        transcript_position = transcript_position,
        estimate = coefs[2, "Value"],
        std_err = coefs[2, "Std.Error"],
        t_value = coefs[2, "t-value"],
        p_value = coefs[2, "p-value"],
        model_error = NA_character_
    )
    
    return(result)
}

binomial_model <- function(transcript_id, transcript_position, df) {
    agg_df <- df %>%
        group_by(sample_name, group_name) %>%
        summarise(
            successes = sum(probability_modified >= 0.5),
            failures = sum(probability_modified < 0.5),
            .groups = "keep"
        ) %>%
        ungroup()

    model <- glm(cbind(successes, failures) ~ group_name,
        data = agg_df,
        family = binomial
    )

    coefs <- summary(model)$coefficients

    result <- data.frame(
        transcript_id = transcript_id,
        transcript_position = transcript_position,
        estimate = coefs[2, "Estimate"],
        std_err = coefs[2, "Std. Error"],
        t_value = coefs[2, "z value"],
        p_value = coefs[2, "Pr(>|z|)"],
        model_error = NA_character_
    )
    
    return(result)
}

beta_binomial_model <- function(transcript_id, transcript_position, df) {
    agg_df <- df %>%
        group_by(sample_name, group_name) %>%
        summarise(
            successes = sum(probability_modified >= 0.5),
            failures = sum(probability_modified < 0.5),
            .groups = "keep"
        ) %>%
        ungroup()

    model <- betabin(cbind(successes, failures) ~ group_name, ~1,
        data = agg_df
    )

    coefs <- summary(model)$coefficients

    result <- data.frame(
        transcript_id = transcript_id,
        transcript_position = transcript_position,
        estimate = coefs[2, "Estimate"],
        std_err = coefs[2, "Std. Error"],
        t_value = coefs[2, "z value"],
        p_value = coefs[2, "Pr(> |z|)"],
        model_error = NA_character_
    )
    
    return(result)
}

# ==============================
# Data loading and transformation
# ==============================

logit <- function(p) {
    eps <- 1e-10
    log((p + eps) / (1 - p + eps))
}

fetch_dataframe <- function(start, end, sites_db, reads_db) {
    con <- dbConnect(duckdb(), dbdir = sites_db, read_only = TRUE)
    dbExecute(con, sprintf("ATTACH '%s' AS all_sites (READONLY);", reads_db))

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
    

    cat("  ", nrow(df), "rows")
    
    df_nested <- df %>%
      mutate(
        transcript_id,
        transcript_position,
        sample_name,
        probability_modified,
        group_name = factor(group_name),
        logit = logit(probability_modified),
        .keep = "none"
      ) %>%
      nest(.by = c(transcript_id, transcript_position))
    
    cat("; ", nrow(df_nested), "groups")
    dbDisconnect(con)
    return(df_nested)
}

# ==============================
# Model application
# ==============================

# Function to apply linear model to each site
apply_model <- function(transcript_id, transcript_position, df) {
    result <- tryCatch(
        {
            # Check if we have both treatment groups
            if (length(unique(df$group_name)) < 2) {
                stop("Only one level in group_name; cannot fit model.")
            }

            beta_binomial_model(transcript_id, transcript_position, df)
        },
        error = function(e) {
            # Return default result on error
            data.frame(
                transcript_id = transcript_id,
                transcript_position = transcript_position,
                estimate = NA_real_,
                std_err = NA_real_,
                t_value = NA_real_,
                p_value = NA_real_,
                model_error = e$message
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
            type = "integer", default = 0,
            help = "Start index for data processing [default=%default]", metavar = "number"
        ),
        make_option(c("--end"),
            type = "integer", default = 199999,
            help = "End index for data processing [default=%default]", metavar = "number"
        ),
        make_option(c("--output"),
            type = "character", default = "model_output.tsv",
            help = "Output TSV filename [default=%default]", metavar = "character"
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
    cat("  Sites Database:", args$sites_database, "\n")
    cat("  Reads Database:", args$reads_database, "\n")
    cat("  Start index:", args$start, "\n")
    cat("  End index:", args$end, "\n")
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
  estimate = numeric(n_rows),
  std_err = numeric(n_rows),
  t_value = numeric(n_rows),
  p_value = numeric(n_rows),
  model_error = character(n_rows)
)

first_iter = TRUE

start_time <- Sys.time()

INTERVAL <- 5000
output_list <- list()
for (offset in seq(args$start, args$end - 1, by = INTERVAL)) {
    start <- offset
    end <- min(offset + INTERVAL - 1, args$end)

    cat("Processing rows", start, "to", end, "...\n")

    batch <- fetch_dataframe(start, end, args$sites_database, args$reads_database)
    
    results_df <- batch %>%
      pmap(~ {
        apply_model(..1, ..2, ..3)
      }) %>%
      list_rbind()
    
    write.table(
      results_df,
      args$output,
      quote=FALSE,
      sep="\t",
      row.names=FALSE,
      col.names=first_iter,
      append=!first_iter
    )
    
    first_iter <- FALSE

    cat("\n")
}

end_time <- Sys.time()
time_taken <- end_time - start_time

cat("\nProcessing completed in", format(time_taken), "\n")
cat("Results written to ", args$output, "...\n")
cat("Analysis complete\n")
