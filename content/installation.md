---
title: Installation
hide:
  - navigation
---

You will need:

- Nextflow
- Docker **or** Singularity (Apptainer)
- System Python version >= 3.9 with pip installed
- Reference genome and transcriptome
- Pre-modification-analysed data from Dorado or m<sup>6</sup>Anet, either in modBAM file or as a table of modification analyses

```bash title="bash: check dependencies and install Mako"
# load nextflow, docker/singularity modules as needed
modules load nextflow apptainer

# check Python version is sufficient and pip exists
python3 -c "import sys,pip; sys.exit(sys.version_info<(3,9))" && echo "Python OK" || echo "Python FAIL"

# download the pipeline
git clone https://github.com/shimlab/mako.git && cd mako

# check mako runs successfully
nextflow run main.nf --help
```