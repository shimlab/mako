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