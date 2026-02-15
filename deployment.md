---
title: Deployment
layout: default
nav_order: 4
---

## Executors

Mako is a Nextflow pipeline intended to be deployed on high performance computing (HPC) systems. For supported scheduler systems, see the [Nextflow documentation (Executors)](https://www.nextflow.io/docs/latest/executor.html). The pipeline was tested to work with the [SLURM workload manager](https://slurm.schedmd.com/overview.html).

### Execution profiles

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

## Containerisation

To run this pipeline, it is strongly recommended to use Docker or Singularity/Apptainer. This allows us to ensure you are using tested versions of all dependencies are bundled within the image, and it helps simplify deployment for everyone. If you do not, you should ensure that all dependencies are installed and available in your environment.

If you are unable to use containers through Nextflow (strongly recommended), we release images with almost all dependencies bundled on GitHub Packages for:

- Docker: [`ghcr.io/olliecheng/mako_main_docker`](https://github.com/users/olliecheng/packages/container/package/mako_main_docker)
- Singularity/Apptainer: [`ghcr.io/olliecheng/mako_main_singularity`](https://github.com/users/olliecheng/packages/container/package/mako_main_singularity)  
  This is an ORAS endpoint, so Singularity can pull without first needing to convert from Docker images, which can take a long time. Do not use this image with Docker, it will fail.

If you are using these images manually, make sure to use a tagged version, as each version is tagged alongside the Mako build commit that it supports.

### Containerless deployment

To install the dependencies manually, you can install necessary software using [the Dockerfile and build scripts](https://github.com/shimlab/mako/tree/main/image) as a guide. See `install_R_dependencies.R` and `requirements.txt` for R and Python dependencies respectively.
