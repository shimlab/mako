---
title: Getting Started
hide:
  - navigation
---

This tutorial provides a worked example of applying Mako to Dorado-generated test .modBAM files, from downloading provided example data through to viewing the results with Makoview.

## 1. Install Mako

Detailed instructions can be found in [Installation](installation.md). In short, you will need Nextflow, Docker or Singularity, and a system Python version >= 3.9. You can check with:

```bash
# load nextflow, docker/singularity modules as needed
modules load nextflow apptainer

# check Python version is sufficient and pip exists
python3 -c "import sys,pip; sys.exit(sys.version_info<(3,9))" && echo "Python OK" || echo "Python FAIL"
```

## 2. Create the working directory

```bash title="bash"
git clone https://github.com/shimlab/mako.git mako_example
cd mako_example

mkdir example_data references results
```

The commands in the remainder of this tutorial should be run from this directory.

## 3. Download example data and references

```bash title="bash"
# download example data
wget -O- 'https://zenodo.org/records/21698223/files/example_mako_input.tar?download=1' \
    | tar -xC example_data

# download references
wget -P references \
    'https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_48/gencode.v48.chr_patch_hapl_scaff.annotation.gtf.gz' \
    'https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_48/gencode.v48.transcripts.fa.gz' \
    'https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_48/GRCh38.p14.genome.fa.gz'

gunzip references/*.gz
```

The `mako` repository comes preloaded with an example samplesheet, `samplesheet.example.csv`,
which has the reads, sample names, and groups preloaded.

<details>
<summary>Contents of the example samplesheet</summary>

<br />
More information on the format of the samplesheet can be found in <a href="../usage/#samplesheet">Usage</a>.

```csv title="samplesheet.example.csv"
name,group,path_modbam
H1975,adenocarcinoma,example_data/H1975.filtered.bam
HCC827,adenocarcinoma,example_data/HCC827.filtered.bam
H2228,adenocarcinoma,example_data/H2228.filtered.bam
H146,sclc_a,example_data/H146.filtered.bam
SHP77,sclc_a,example_data/SHP77.filtered.bam
H69,sclc_a,example_data/H69.filtered.bam
```

</details>


## 4. Run Mako

Depending on whether you have Singularity or Docker, please use the corresponding commands below to run Mako. Please provide at least 16 CPU cores and 16GB of RAM (for
instance, for SLURM, by using `sinteractive --cpus-per-task=16 --mem=16G`). The expected runtime for this example is ~10 minutes.

=== "Singularity (Apptainer)"
    ```bash
    # Run mako
    nextflow run main.nf \
      -profile         singularity \
      --samplesheet    samplesheet.example.csv \
      --dataset_name   example \
      --outdir         results \
      --input_format   modbam \
      --mod_threshold  0.5 \
      --genome         references/GRCh38.p14.genome.fa \
      --transcriptome  references/gencode.v48.transcripts.fa \
      --gtf            references/gencode.v48.chr_patch_hapl_scaff.annotation.gtf
    ```

=== "Docker"
    ```bash
    # Run mako
    nextflow run main.nf \
      -profile         docker \
      --samplesheet    samplesheet.example.csv \
      --dataset_name   example \
      --outdir         results \
      --input_format   modbam \
      --mod_threshold  0.5 \
      --genome         references/GRCh38.p14.genome.fa \
      --transcriptome  references/gencode.v48.transcripts.fa \
      --gtf            references/gencode.v48.chr_patch_hapl_scaff.annotation.gtf
    ```

Among various Mako outputs, the differential modification analysis output is stored in `results/differential/model_calls.tsv`. 

For further description of outputs, please see [Output](output.md).

!!! tip
    Whilst Mako can be ran locally, Mako is designed to be run on an HPC system with an appropriate job executor, such as SLURM.
    More information on how to run Mako on your specific system can be found in [Deployment](deployment.md).

    In short: Mako requires either Singularity or Docker; beyond that, you should use your HPC's job executor or,
    if your institution supports it, a pre-made `nf-core/configs` configuration.

## 5. Run Makoview

Mako comes with an interactive application called **_Makoview_** which can be used to visualise the results once the pipeline has finished. You can see an interactive demo of Makoview here: [https://shimlab.github.io/makoview/gene](https://shimlab.github.io/makoview/gene).

Start Makoview by running the below.
```console
$ ./results/makoview/launch_makoview.sh

INFO:     Started server process [18394]
INFO:     Waiting for application startup.

... abridged ...

============================================================
  Makoview is running on http://127.0.0.1:52348

  Tip: advice on accessing Makoview from other devices
       using SSH port forwarding can be found in the docs:
       https://shimlab.github.io/mako/makoview
============================================================
```

In this case, Makoview can be accessed by opening the given address `http://127.0.0.1:52348` on any standard web browser.

!!! tip
    On HPC systems where web browsers are sometimes not available, if you have SSH access, you can port forward the web server to your local machine for access via web browser.

    For further information, please see [Makoview](makoview.md).