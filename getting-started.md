---
title: Getting Started
layout: default
nav_order: 2
---

## Quick start

You will need:

- Nextflow
- Docker **or** Singularity (Apptainer)
- Reference genome and transcriptome
- Your data in .pod5 format **or** pre-modification-called data from Dorado or m<sup>6</sup>Anet

---

Prepare a samplesheet CSV `samplesheet.csv` file with the format:

<table>
<thead>
<tr><th>name</th><th>group</th><th>path_dorado</th><th>path_m6anet</th></tr>
</thead>
<tr><td>sample1</td><td>group1</td><td>/path/to/dorado/reads.bam</td><td>/path/to/m6anet/data.indiv_proba.csv</td></tr>
</table>
```
name,group,path_dorado,path_m6anet
sample1,group1,/path/to/dorado/reads.bam,/path/to/m6anet/data.indiv_proba.csv
```

If you only have one of Dorado or m6Anet data, leave the other blank.

Run the pipeline:

```sh
# load nextflow, docker/singularity modules as needed
modules load nextflow apptainer

# download the pipeline
git clone https://github.com/shimlab/mako.git && cd mako

# show all configuration settings
nextflow run main.nf --help

nextflow run main.nf \
    -profile docker  \    # OR  -profile singularity  OR  -profile `my_institution`
    --dataset_name <name> \
    --samplesheet <samplesheet.csv> \
    --outdir results \
    --transcriptome <transcriptome.fasta> \
    --gtf <annotation.gtf>
```

{: .highlight }
Configuration settings can be found in [Configuration](configuration).

{: .note }
If your institution has an [nf-core configuration](https://nf-co.re/configs/) available, you can access it through `-profile` i.e. `-profile wehi` to use the WEHI Milton HPC. See [Execution Profiles](deployment#execution-profiles) for more.

## Running makoview

Once the pipeline has finished, you can run the visualisation tool `makoview` using:

```bash
export MAKO_OUTPUT_DIR="/data/gpfs/projects/punim0614/occheng/epi_differential/pipeline/runs/longbench/results"
export MODCALLER="dorado"  # either "dorado" or "m6anet"
export DIFFERENTIAL_MODEL="adaptive_binomial"
uvx makoview \
  --differential-results $MAKO_OUTPUT_DIR/differential/$MODCALLER/${DIFFERENTIAL_MODEL}_fits.tsv \
  --modification-db $MAKO_OUTPUT_DIR/modcall/$MODCALLER/all_sites.duckdb \
  --port 8000
```

See [makoview](makoview) for more information on alternative installation methods for Makoview and remote forwarding.
