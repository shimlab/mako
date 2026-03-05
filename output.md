---
title: Output
layout: default
nav_order: 5
---

This page describes the output files and folder structure of Mako.

```
└── 📁 results
    ├── 📁 basecall
    │   └── 📁 <sampleX>
    │       ├── basecalled_sorted.bam
    │       ├── basecalled_sorted.bam.bai
    │       ├── <sampleX>_fastqc.html
    │       ├── <sampleX>_fastqc.zip
    │       ├── <sampleX>.flagstat.txt
    │       └── 📁 nanoplot
    │           └── * assorted nanoplot output files
    ├── 📁 modcall
    │   └── 📁 dorado
    │       ├── all_sites.duckdb
    │       └── <sample>
    │           ├── modifications_<sample>.tsv
    │           ├── pileup_<sample>.bed.gz
    │           └── pileup_<sample>.bed.gz.tbi
    └── 📁 differential
        ├── 📁 dorado
        │   ├── <model>_fits.tsv
        │   ├── differential_sites_<model>.duckdb
        │   ├── 📁 segments
        │   │   └── <model>_<start>_to_<end>.parquet
        │   ├── segments.csv
        │   ├── selected_sites.db
        │   └── subset.duckdb
        └── 📁 m6anet
            ├── <model>_fits.tsv
            ├── differential_sites_<model>.duckdb
            ├── 📁 segments
            │   └── <model>_<start>_to_<end>.parquet
            ├── segments.csv
            ├── selected_sites.db
            └── subset.duckdb
```
