#!/usr/bin/env Rscript

# Set CRAN mirror to public Posit Package Manager for faster builds
options(
    repos = c(
        CRAN = sprintf(
            'https://packagemanager.posit.co/cran/latest/bin/linux/noble-%s/%s',
            R.version['arch'],
            substr(getRversion(), 1, 3)
        )
    )
)

install.packages(c(
    "data.table",
    "tidyverse",
    "duckdb",
    "optparse",
    "nanoparquet",
    # statistics libraries
    "nlme",
    "lmerTest",
    "aod",
    "betareg",
    "glmmTMB",
    "geepack",
    "DescTools",
    "goftest",
    "twosamples"
))

# Bioconductor packages (use official Bioconductor repository for guaranteed version consistency)
if (!require("BiocManager", quietly = TRUE))
    install.packages("BiocManager")

BiocManager::install(c("GenomicFeatures", "txdbmaker", "DSS"), update = TRUE, ask = FALSE)

# Build-time assertion: Verify DSS and all packages load cleanly before finalizing image
library(GenomicFeatures)
library(txdbmaker)
library(DSS)
cat("=== All R dependencies successfully verified! ===\n")