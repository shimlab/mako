---
title: Getting Started
hide:
  - navigation
---

This tutorial provides an example of applying Mako to Dorado-generated modBam files, from downloading provided example data through to viewing the results with Makoview.

## 1. Install Mako

Please follow [Installation](installation.md) to install Mako

## 2. Create the working directory

```bash title="bash"
mkdir -p mako-tutorial # This directory can be anywhere in general, not necessarily inside the mako installation directory
cd mako-tutorial
```

The commands in the remainder of this tutorial should be run from this directory.

## 3. Download example data

```bash title="bash"
mkdir -p data

# Download example data
wget -O data/example_mako_input.tar https://zenodo.org/records/21698223/files/example_mako_input.tar?download=1

# Extract example data
tar -xf data/example_mako_input.tar -C data
```

## 4. Download matching genome and transcriptome references

```bash title="bash"
mkdir -p references

# Download references
wget -P references https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_48/gencode.v48.chr_patch_hapl_scaff.annotation.gtf.gz
wget -P references https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_48/gencode.v48.transcripts.fa.gz
wget -P references https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_48/GRCh38.p14.genome.fa.gz

# Extract references
gunzip references/*.gz
```

## 4. Create the samplesheet

Mako uses a CSV samplesheet to describe the samples that will be analysed.

In the current directory, create `samplesheet.csv` with the following content.

!!! note
    Please replace `<mako_tutorial_dir>` in the following with your Mako installation directory.

```csv title="samplesheet.csv"
name,group,path_modbam
H1975,adenocarcinoma,<mako_tutorial_dir>/data/H1975.filtered.bam
HCC827,adenocarcinoma,<mako_tutorial_dir>/data/HCC827.filtered.bam
H2228,adenocarcinoma,<mako_tutorial_dir>/data/H2228.filtered.bam
H146,sclc_a,<mako_tutorial_dir>/data/H146.filtered.bam
SHP77,sclc_a,<mako_tutorial_dir>/data/SHP77.filtered.bam
H69,sclc_a,<mako_tutorial_dir>/data/H69.filtered.bam
```

## 5. Run Mako

!!! note
    Please replace `<mako_dir>` in the following with your Mako installation directory.

    Please provide at least 32 CPU cores and 32 GB of RAM for Mako to run.

    This step will likely take ~10 hours.

    Further performance optimisation of Mako is currently being developed

```bash title="bash"
# Create output results directory
mkdir -p results

# Run mako
nextflow run <mako_dir>/main.nf \
  -profile singularity \
  --samplesheet samplesheet.csv \
  --dataset_name example \
  --outdir results \
  --input_format modbam \
  --mod_threshold 0.5 \
  --genome references/GRCh38.p14.genome.fa \
  --transcriptome references/gencode.v48.transcripts.fa \
  --gtf references/gencode.v48.chr_patch_hapl_scaff.annotation.gtf
```

Among various Mako outputs, the differential modification analysis output is stored in `results/differential/model_calls.tsv`. 

For further description of outputs, please see [Output](output.md).

## 6. Run Makoview

Mako comes with an interactive application called **_Makoview_** which can be used to visualise the results once the pipeline has finished. You can see an interactive demo of Makoview here: [https://shimlab.github.io/makoview/gene](https://shimlab.github.io/makoview/gene).

Start Makoview by running the below.
```bash title="bash"
results/makoview/launch_makoview.sh
```

This will output the web server that Makoview is running on, for example:
```
Makoview is running on http://127.0.0.1:52348
```

In this case, Makoview can be accessed by opening the given address `http://127.0.0.1:52348` on any standard web browser.

!!! tip
    On HPC systems where web browsers are sometimes not available, if you have SSH access, you can port forward the web server to your local machine for access via web browser.

    For further information, please see [Makoview](makoview.md).