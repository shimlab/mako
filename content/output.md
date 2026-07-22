---
title: Output
hide:
  - navigation
---

## Key outputs
### Differentially modified output spreadsheet
Mako writes a TSV file of the following format:
```tsv title="differential/model_calls.tsv"
transcript_id       transcript_position  rname                                                                                                               chr   chr_position  estimate              std_err              test_statistic        p_value               model_type     error  error_message        bh_corrected_p_value
ENST00000000233.10  145                  ENST00000000233.10|ENSG00000004059.11|OTTHUMG00000023246.7|OTTHUMT00000059567.3|ARF5-201|ARF5|1032|protein_coding|  chr7  127588556.0   0.28768207247673017   0.7936258469536126   0.3624908054356062    0.7169852932245568    binomial       False                       0.9640344056139295
ENST00000000233.10  178                  ENST00000000233.10|ENSG00000004059.11|OTTHUMG00000023246.7|OTTHUMT00000059567.3|ARF5-201|ARF5|1032|protein_coding|  chr7  127589106.0   0.1960495215844195    0.3689160678596121   0.531420392507882     0.5951274932453505    binomial       False                       0.9373782917763457
ENST00000000233.10  191                  ENST00000000233.10|ENSG00000004059.11|OTTHUMG00000023246.7|OTTHUMT00000059567.3|ARF5-201|ARF5|1032|protein_coding|  chr7  127589119.0   -0.7239188392266889   0.5913944974137653   -1.2240878844704635   0.220919075964312     binomial       False                       0.7249549006922915
ENST00000000233.10  195                  ENST00000000233.10|ENSG00000004059.11|OTTHUMG00000023246.7|OTTHUMT00000059567.3|ARF5-201|ARF5|1032|protein_coding|  chr7  127589123.0   0.49352123800261677   0.2511703485342725   1.9648865436649072    0.04942737051245885   binomial       False                       0.35089572319916346
ENST00000000233.10  229                  ENST00000000233.10|ENSG00000004059.11|OTTHUMG00000023246.7|OTTHUMT00000059567.3|ARF5-201|ARF5|1032|protein_coding|  chr7  127589157.0   -1.43281437674045     0.6961539005509063   -2.0581862367022326   0.039572259287345535  binomial       False                       0.307126201446428
...
```

| <div style="width:12em">Column</div> | Description |
|---|---|
| `transcript_id` | Transcript ID the site belongs to, extracted from `rname` |
| `transcript_position` | Transcript position of the site |
| `rname` | Full reference transcript annotation string |
| `chr` | Chromosome of the site |
| `chr_position` | Genomic position of the site |
| `estimate` | Effect size estimate from the differential model |
| `std_err` | Standard error of the estimate |
| `test_statistic` | Test statistic |
| `p_value` | Raw p-value for the test of differential modification at this site |
| `model_type` | Statistical model used to call the site (e.g. `binomial`, `homo_norm`, `hetero_norm`, `beta_binomial`) |
| `error` | Whether the model fit failed for this site (`True`/`False`) |
| `error_message` | Error message if `error` is `True`, otherwise typically blank/NA |
| `bh_corrected_p_value` | Benjamini–Hochberg corrected p-value |

### Makoview launch script
[Makoview](makoview.md) is a visualisation tool to view the output of Mako.
It is automatically installed and can be launched using the script `makoview/launch_makoview.sh`.

# All outputs

```title="Directory tree of Mako outputs"
outdir/
├── basecall
│   ├── <sample, e.g. H146>
│   │   ├── basecalled_sorted.bam
│   │   ├── basecalled_sorted.bam.bai
│   │   ├── H146_fastqc.html
│   │   ├── H146_fastqc.zip
│   │   ├── H146.flagstat.txt
│   │   └── 📁 nanoplot
│   ├── 📁 nanocomp
├── db
│   ├── coverage.duckdb
│   └── reads.duckdb
├── differential
│   ├── model_calls.tsv
│   ├── segments/*.parquet
│   ├── segments.csv
│   └── sites.duckdb
├── makoview
│   ├── launch_makoview.sh
│   └── 📁 makoview_venv
└── modcall
    └── <sample, e.g. H146>
        ├── modifications_H146.tsv.gz
        ├── pileup_H146.bed.gz
        └── pileup_H146.bed.gz.tbi
```
### `basecall/` directory
Per-sample basecalling and alignment QC.

| File | Description |
|---|---|
| `basecalled_sorted.bam(.bai)` | Coordinate-sorted, indexed alignments from dorado |
| `{sample}_fastqc.html/.zip` | FastQC report on basecalled reads |
| `{sample}.flagstat.txt` | `samtools flagstat` summary |
| `nanoplot/` | Per-sample NanoPlot QC report |
| `nanocomp/` | Cross-sample comparison (NanoComp) — read length, N50, throughput, identity, quality plots |

### `modcall/` directory
Per-sample RNA modification calls (modkit).

| File | Description |
|---|---|
| `pileup_{sample}.bed.gz(.tbi)` | bedMethyl pileup of per-site modification stats |
| `modifications_{sample}.tsv.gz` | Read-level modification calls |

### `db/` directory
Aggregated databases used internally by the differential step.

| File | Description |
|---|---|
| `reads.duckdb` | Read-level modification data across samples |
| `coverage.duckdb` | Per-site coverage across samples |

### `differential/` directory
Differential modification analysis outputs.

| File | Description |
|---|---|
| `model_calls.tsv` | Final differential calls |
| `sites.duckdb` | Selected/filtered sites used for testing |
| `segments.csv` | Genomic segments used to parallelise analysis |
| `segments/*.parquet` | Per-segment intermediate results |

### `makoview/`
Interactive results viewer.

| File | Description |
|---|---|
| `launch_makoview.sh` | Script to launch the viewer |
| `makoview_venv/` | Bundled Python virtual environment for the viewer |
