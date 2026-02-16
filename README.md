<p align="center"><img src="https://github.com/shimlab/mako/blob/main/assets/logo_with_name.png" height=128 align="center" /></p>

**Differential RNA modification calling at the isoform resolution using Nanopore direct RNA sequencing**

Docs: https://shimlab.github.io/mako

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.10.0-23aa62.svg)](https://www.nextflow.io/) [![Docker](https://img.shields.io/badge/docker-enabled-0db7ed.svg)](https://www.docker.com/) [![Singularity](https://img.shields.io/badge/singularity-enabled-1d355c.svg)](https://sylabs.io/guides/3.0/user-guide/index.html)

## Introduction
Mako is a bioinformatics pipeline designed for differential RNA modification calling at the isoform resolution using Nanopore direct RNA sequencing. It takes a samplesheet and output from Dorado and/or m6Anet, and applies various statistical methods to identify differentially modified sites between experimental conditions.

Mako will also produce interactive visualisations for quality control and assessment of sites through the `makoview` tool.

## Steps

1. Sample and read QC
2. Site-level aggregation, filtering, and selection
3. Choice of differential analysis methods:
    1. Linear mixed-effects models
    2. Modkit
4. Visualization of results via *makoview*

![mako pipeline diagram](https://github.com/shimlab/mako/blob/main/assets/pipeline_diagram.svg)


## Documentation
Please refer to the [documentation](https://shimlab.github.io/mako/) for detailed instructions on how to use the pipeline, including input requirements, parameter settings, and output interpretation.


## Installation
Read the [quick start](https://shimlab.github.io/mako/getting-started.html#quick-start). But if you're in a rush:
``` bash
# Clone the repository
git clone https://github.com/shimlab/mako && cd mako

# Test the pipeline
nextflow run main.nf --help
nextflow run main.nf -profile testing
```

## Citations

Mako does not have a preprint yet. Please check back later for updates.

## Contributors

This package is developed and maintained by Yulin Wu, Oliver Cheng, Sophie Wharrie and Heejung Shim in the Shim Lab at the University of Melbourne.

Please leave an issue if you find a bug or have a feature request. Thank you!