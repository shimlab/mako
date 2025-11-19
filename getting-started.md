---
title: Getting Started
layout: default
nav_order: 2
---

# Quick start
You will need:
* Nextflow
* Docker **or** Singularity (Apptainer)
* Reference genome and transcriptome
* Your data in .pod5 format **or** pre-modification-called data from Dorado or m<sup>6</sup>Anet

---

Prepare a samplesheet CSV `samplesheet.csv` file with the format:

<table>
<thead>
<tr><th>name</th><th>group</th><th>path_dorado</th><th>path_m6anet</th><th>path_pod5</th></tr>
</thead>
<tr><td>sample1</td><td>group1</td><td></td><td></td><td>pod5_path</td></tr>
</table>
```
name,group,path_dorado,path_m6anet,path_pod5
sample1,group1,,,pod5_path
```

Run the pipeline:
```sh
# load nextflow, docker/singularity modules as needed
modules load nextflow apptainer

git clone https://github.com/shimlab/mako.git
cd mako
nextflow run main.nf \
    -profile docker  \    # OR  -profile singularity  OR  -profile `my_institution`
    --dataset_name <name> \
    --input <samplesheet.csv> \
    --outdir results \
    --mod_method dorado \
    --diff_method lmer \
    --genome <genome.fastq> \
    --transcriptome <transcriptome.fasta>
```

{: .highlight }
Configuration settings can be found in [Configuration](configuration).

{: .note }
If your institution has an [nf-core configuration](https://nf-co.re/configs/) available, you can access it through `-profile` i.e. `-profile wehi` to use the WEHI Milton HPC. See [Execution Profiles](#execution-profiles) for more.

# Containerisation

To run this pipeline, it is strongly recommended to use Docker or Singularity/Apptainer. This allows us to ensure you are using tested versions of all dependencies are bundled within the image, and it helps simplify deployment for everyone. We strongly recommend you run the pipeline with Docker or Singularity/Apptainer support. If you do not, you should ensure that all dependencies are installed and available in your environment — see [Containerless deployment](#containerless-deployment) for more information.

# Execution profiles
This pipeline supports the [nf-core/configs pre-made configurations](https://nf-co.re/configs/), as well as a custom pre-configured profile for the University of Melbourne's Spartan HPC.

```sh
# for users of the Spartan HPC system at the University of Melbourne, you can use the pre-configured profile:
nextflow run main.nf -profile spartan

# for users of an nf-core/config compatible HPC system, you can use that profile as well:
nextflow run main.nf -profile [institution]

# if your institution does not have a preconfigured profile, you can use the default Docker or Singularity profiles:
# typically, HPC systems nowadays use Singularity/Apptainer, which is preferred.
nextflow run main.nf -profile docker
nextflow run main.nf -profile singularity
```

# Containerless deployment
Two container images are used: one for Dorado basecalling, and one for the analysis pipeline. If you wish to run the pipeline without Docker or Singularity/Apptainer, you will need to ensure that all dependencies are installed and available in your environment.

You should install Dorado using your preferred method, or a module loader if available. To install other dependencies, you can install necessary software using [the Dockerfile](https://github.com/link_to_dockerfile!) as a guide. See `install_R_dependencies.R` and `requirements.txt` for R and Python dependencies respectively.

```Dockerfile
##### pre-install...

# Install dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    r-base-core python3 python3-pip samtools tabix \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --break-system-packages -r requirements.txt

# install Modkit v0.5.0
RUN wget "https://github.com/nanoporetech/modkit/releases/download/v0.5.0/modkit_v0.5.0_u16_x86_64.tar.gz" -O modkit.tar.gz \
    && mkdir modkit && tar -xzf modkit.tar.gz --strip-components=1 -C modkit && rm modkit.tar.gz

# install R dependencies
COPY install_R_dependencies.R .
RUN Rscript install_R_dependencies.R

##### post-install...
```