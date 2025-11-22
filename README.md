# Differential RNA Modifications Nanopore

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.10.0-23aa62.svg)](https://www.nextflow.io/) [![Docker](https://img.shields.io/badge/docker-enabled-0db7ed.svg)](https://www.docker.com/) [![Singularity](https://img.shields.io/badge/singularity-enabled-1d355c.svg)](https://sylabs.io/guides/3.0/user-guide/index.html)

## Introduction
<name> is a bioinformatics pipeline designed for the analysis of differential RNA modifications using Oxford Nanopore Technologies (ONT) RNA004 direct RNA sequencing data. It takes a samplesheet and POD5 files as input, performs basecalling and alignment, and then applies various statistical methods to identify differentially modified sites between experimental conditions. If you already have pre-basecalled data or m6Anet results, you can skip the basecalling step and directly analyze the modification data as well.

1. Basecalling with dorado
2. Choice of modification caller:
    1. Dorado
    2. m6Anet
2. Site-level aggregation, filtering, and selection
3. Choice of differential analysis methods:
    1. Linear mixed-effects models
    2. Modkit
4. Visualization of results

## Installation
To run this pipeline, you will need Nextflow and either Docker or Singularity/Apptainer. The latest versions of these tools are recommended, and the pipeline has been tested to work on Nextflow 24.10.2. You likely will need to load the Nextflow and Apptainer modules on your HPC system, such as using a command like `module load nextflow apptainer`.

Note that this pipeline has been designed with containerisation in mind, and all dependencies are bundled within the image. We strongly recommend you run the pipeline with Docker or Singularity/Apptainer support. If you do not, you should ensure that all dependencies are installed and available in your environment. The `images/Dockerfile` directory contains further information about the dependencies of this pipeline.

For users at the University of Melbourne, there is a pre-configured profile for the [Spartan HPC](https://spartan.unimelb.edu.au/). You can use this profile by running `-profile spartan`.

This pipeline has built-in support for `nf-core/configs`. If your institution has an `nf-core` config available, you can access it through the `-profile` i.e. `-profile wehi` to use the [WEHI Milton HPC](https://nf-co.re/configs/wehi/).


## Usage
> [!NOTE]
> This pipeline is designed for use with Nextflow and is intended to be run on HPC clusters. Make sure to test your setup using `-profile testing` to make sure that everything is set up correctly before running the full pipeline.

You must prepare a sample sheet in CSV format with the following columns:

| Column        | Description                                 |
| ------------- | ------------------------------------------- |
| `name`        | Sample identifier                           |
| `group`       | Experimental group                          |
| `path_dorado` | Path to pre-basecalled BAM files (optional) |
| `path_m6anet` | Path to m6Anet results (optional)           |
| `path_pod5`   | Path to POD5 files                          |

```csv
name,group,path_dorado,path_m6anet,path_pod5
mar_3_control,control,,,datasets/raw/mar_3_control
mar_3_treat,treat,,,datasets/raw/mar_3_treat
...
```

where `mar_3_control` looks like this:

```sh
$ tree datasets/raw/mar_3_control
├── PAS85652_12528808_d05d1795_0.pod5
├── PAS85652_12528808_d05d1795_10.pod5
├── PAS85652_12528808_d05d1795_11.pod5
└── ...
```

Each row represents a separate sample. Under most circumstances, the `path_dorado` and `path_m6anet` columns should be left empty, as the pipeline will generate these files. However, if you have pre-basecalled data or m6Anet results, you can specify their paths in the respective columns to skip the basecalling step.

### Installation

You can directly run the pipeline from GitHub: `nextflow run shimlab/differential-RNA-modifications-nanopore <...params>`. Alternatively, you can clone the repository and run it locally:

``` bash
# Clone the repository
git clone https://github.com/shimlab/differential-RNA-modifications-nanopore
cd differential-RNA-modifications-nanopore

# Test the pipeline
nextflow run main.nf -profile testing
```

### Basic Usage

``` bash
nextflow run main.nf \
  --samples samples.csv \
  --method dorado \
  --diffanalysis lmer \
  --outdir results \
  -profile docker
```

## Parameters

| Parameter        | Default              | Description                             |
| ---------------- | -------------------- | --------------------------------------- |
| `samples`        | `./samples.csv`      | Path to sample sheet                    |
| `method`         | `['dorado']`         | Detection method(s): `dorado`, `m6anet` |
| `diffanalysis`   | `['lmer', 'modkit']` | Statistical method(s)                   |
| `outdir`         | `results`            | Output directory                        |
| `dataset_name`   | `marmosets`          | Dataset identifier                      |
| `genome`         | N/A                  | Reference genome FASTA                  |
| `transcriptome`  | N/A                  | Reference transcriptome FASTA           |
| `min_reads`      | `20`                 | Minimum read coverage per site          |
| `prob_threshold` | `0.0`                | Modification probability threshold      |
| `n_threads`      | `16`                 | Number of threads                       |
| `batch_size`     | `50`                 | Batch size for processing               |


## Execution Profiles
``` bash
# you should do a test run first to ensure everything is set up correctly!
nextflow run main.nf -profile testing

# for users of the Spartan HPC system at the University of Melbourne, you can use the pre-configured profile:
nextflow run main.nf -profile spartan

# for users of an nf-core/config compatible HPC system, you can use that profile as well:
nextflow run main.nf -profile [institution]

# if your institution does not have a preconfigured profile, you can use the default Docker or Singularity profiles:
# typically, HPC systems nowadays use Singularity/Apptainer, which is preferred.
nextflow run main.nf -profile docker
nextflow run main.nf -profile singularity
```

## Citations

If you use this pipeline, please cite the following tools and methods:

```         
[Citations to be added]
[Dorado, SAMtools, minimap2, m6Anet, Modkit, Spartan]
```

### Contributors

This package is developed and maintained by Sophie Wharrie, Yulin Wu, Oliver Cheng, and Heejung Shim in the Shim Lab at the University of Melbourne.
Please leave an issue if you find a bug or have a feature request. Thank you!