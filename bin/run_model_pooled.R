#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    library(tidyverse)
    library(duckdb)
    library(optparse)
    library(nanoparquet)
    library(DSS)
})


# ==============================
# Models
# ==============================


dss_model <- function(counts_df, threads) {
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
    # In DSS::DMLtest, diff is computed as mu(group1) - mu(group2).
    # To match standard treatment vs control effect convention (Treatment - Control),
    # we pass group1 = treated_samples and group2 = control_samples.
    dml_results <- DSS::DMLtest(
        bsseq_data,
        group1     = treated_samples,
        group2     = control_samples,
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
# Data fetching
# ==============================

fetch_dss_counts <- function(sites_db, reads_db, threshold) {
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
        "
    )

    cat(sprintf("  Aggregating read counts for %d sites in DuckDB SQL...\n", nrow(sites)))
    counts <- dbGetQuery(
        con,
        "
        WITH indexed_sites AS (
            SELECT 
                row_number() OVER (ORDER BY rname, transcript_position) AS site_idx,
                rname, 
                transcript_position
            FROM sites
            WHERE selected = TRUE
        )
        SELECT 
            s.site_idx,
            r.sample_name,
            r.group_name,
            SUM(CASE WHEN r.probability_modified >= ? THEN 1 ELSE 0 END) AS successes,
            COUNT(*) AS total
        FROM indexed_sites s
        JOIN all_sites.reads r ON r.rname = s.rname AND r.transcript_position = s.transcript_position
        WHERE r.ignored = FALSE
        GROUP BY s.site_idx, r.sample_name, r.group_name
        ORDER BY s.site_idx, r.sample_name
        ",
        list(threshold)
    )

    dbDisconnect(con)
    return(list(sites = sites, counts = counts))
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
        make_option(c("--modification-threshold"),
            type = "double", default = 0.5,
            help = "Threshold for binarizing modification status [default=%default]", metavar = "number"
        ),
        make_option(c("--output"),
            type = "character", default = "model_output.parquet",
            help = "Output Parquet filename [default=%default]", metavar = "character"
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

    parser <- OptionParser(option_list = option_list, description = "Run pooled DSS analysis on RNA modification data")
    args <- parse_args(parser, convert_hyphens_to_underscores = TRUE)

    # Validate required arguments
    if (!file.exists(args$sites_database) | !file.exists(args$reads_database)) {
        print_help(parser)
        stop("Sites database file path is required (--sites-database) and reads database file path is required (--reads-database)")
    }

    if (is.null(args$threads) || is.na(args$threads) || args$threads <= 0L) {
        stop("A valid positive integer for --threads is required.")
    }

    cat("Parameters:\n")
    cat("  Reads database:", args$reads_database, "\n")
    cat("  Modification threshold:", args$modification_threshold, "\n")
    cat("  Model: dss\n")
    cat("  Threads:", args$threads, "\n")
    cat("  Output file:", args$output, "\n\n")
    cat("  GTF file:", args$gtf, "\n\n")

    return(args)
}

# ==============================
# Main script execution
# ==============================

args <- get_args()

start_time <- Sys.time()

# Fetch sites and aggregated per-sample counts directly from DuckDB SQL
dss_data <- fetch_dss_counts(args$sites_database, args$reads_database, args$modification_threshold)

cat(sprintf("Processing all %d sites with DSS...\n", nrow(dss_data$sites)))

dss_results <- if (nrow(dss_data$sites) > 0) {
    dss_model(dss_data$counts, threads = args$threads)
} else {
    # no selected sites: an empty, correctly-typed frame so the join below
    # still produces an output with the right columns
    data.frame(
        site_idx = integer(0), estimate = numeric(0), std_err = numeric(0),
        test_statistic = numeric(0), p_value = numeric(0), drop = logical(0)
    )
}

output_df <- dss_data$sites %>%
    left_join(dss_results, by = "site_idx") %>%
    transmute(
        transcript_id, transcript_position, rname, chr, chr_position,
        estimate, std_err, test_statistic, p_value,
        # a site with no DSS row (shouldn't happen) is dropped rather than
        # silently reported with NA statistics
        drop = coalesce(drop, TRUE),
        model_type = "dss",
        error = FALSE,
        error_message = NA_character_
    )

# write to Parquet
write_parquet(output_df, args$output)

end_time <- Sys.time()
time_taken <- end_time - start_time

cat("\nProcessing completed in", format(time_taken), "\n")
cat("Results written to:", args$output, "...\n")
cat("Analysis complete\n")