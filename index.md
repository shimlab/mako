---
title: Home
layout: home
nav_order: 1
---

## Introduction

Mako is a bioinformatics pipeline designed for the differential analysis of RNA modifications between two groups using Oxford Nanopore Technologies (ONT) direct RNA sequencing data (RNA002 or RNA004). It takes a samplesheet and POD5 files as input, performs basecalling and alignment, and then applies various statistical methods to identify differentially modified sites between experimental conditions.

If you already have pre-basecalled data or m6Anet results, you can skip the basecalling step and directly analyze the modification data as well.

The software is written in Nextflow and utilises Docker/Singularity containerisation for reproducibility and ease of installation.

{: .highlight }
**See [Getting Started](getting-started) for instructions on how to install and run the pipeline.**

{: .note }
**mako** is in active development and not all features are supported. See [Configuration](configuration) for a list of what features are in-progress.

---

![assets](./assets/diagram.svg)

---

## Steps of the pipeline

1. Sample and read QC
2. Site-level aggregation, filtering, and selection
3. Choice of differential analysis methods:
   1. Either binomial or beta-binomial, depending on the dispersion (**default**)
   2. Binomial
   3. Beta-binomial
   4. Homoscedastic normal
   5. Heteroscedastic normal
4. Visualization of results via _makoview_
