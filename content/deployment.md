---
title: Deployment
hide:
  - navigation
---

Mako is a Nextflow pipeline intended to be deployed on high performance computing (HPC) systems.

## Profiles

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

## Executors
By default when running with the `-profile docker` or `-profile singularity` setting, no [executor](https://docs.seqera.io/nextflow/executor) is set and all jobs will be run locally. It is recommended to run Mako with the executor for your HPC scheduler, such as [SLURM](https://slurm.schedmd.com/overview.html), [PBS](https://www.siemens.com/en-us/products/hpcworks/pbs-professional/), [LSF](https://www.ibm.com/docs/en/spectrum-lsf/10.1.0?topic=lsf-session-scheduler), or the [Sun Grid Engine](https://computing.sas.upenn.edu/gpc/job/sge).

If you are using a preconfigured profile, such as `-profile spartan` or the profiles in `nf-core/configs`, there is a good chance the profile will configure an executor for you by default. If using an executor, you should run `nextflow` from a **login node**, as the executor will manage compute allocation for you.

If you do not use an executor, you should run Mako in an environment (e.g. SLURM node) with at least 16 CPUs and call Mako with:

```sh
nextflow run main.nf -profile docker|singularity -process.cpus 16 
```

## Containerisation

To run this pipeline, it is strongly recommended to use Docker or Singularity/Apptainer. This allows us to ensure you are using tested versions of all dependencies are bundled within the image, and it helps simplify deployment for everyone. If you do not, you should ensure that all dependencies are installed and available in your environment.

If you are unable to use containers through Nextflow (strongly recommended), we release images with almost all dependencies bundled on GitHub Packages for:

- Docker: [`ghcr.io/olliecheng/mako_main_docker`](https://github.com/users/olliecheng/packages/container/package/mako_main_docker)
- Singularity/Apptainer: [`oras://ghcr.io/olliecheng/mako_main_singularity`](https://github.com/users/olliecheng/packages/container/package/mako_main_singularity)  
  This is an ORAS endpoint, so Singularity can pull without first needing to convert from Docker images, which can take a long time. Do not use this image with Docker, it will fail.

If you are using these images manually, make sure to use a tagged version, as each version is tagged alongside the Mako build commit that it supports.

### Containerless deployment

To install the dependencies manually, you can install necessary software using [the Dockerfile and build scripts](https://github.com/shimlab/mako/tree/main/image) as a guide. See `install_R_dependencies.R` and `requirements.txt` for R and Python dependencies respectively. This approach is not officially supported, as we cannot guarantee dependencies will be installed correctly on your machine.
