#!/bin/bash
set -x

rsync --progress --delete -a . spartan:/data/gpfs/projects/punim0614/occheng/epi_differential/pipeline/mako --exclude .git/ --exclude visualisation --exclude work --exclude .nextflow
