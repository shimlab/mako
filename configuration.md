---
title: Configuration
layout: default
nav_order: 3
---

## Parameters

{% include parameters.html %}

## Samplesheet

The samplesheet is a CSV file which contains information about the samples to be analysed in the pipeline. It should have the following columns. **A header is required**. Optional columns should be left empty.

- `name`: a unique name for each sample
- `group`: the experimental group or condition for each sample
- `path_dorado`: (optional) path to pre-basecalled Dorado modification data for each sample.  
  The file should be a .bam file in 'modbam' format i.e. with tags `MM` and `ML`. See the [Dorado documentation](https://software-docs.nanoporetech.com/dorado/latest/basecaller/mods/) for more information.
- `path_m6anet`: (optional) path to pre-basecalled m6Anet modification data for each sample  
  The file should be a .csv file, most likely `data.indiv_proba.csv`, with columns `transcript_id, transcript_position, read_index, probability_modified`.

Two groups should be provided to call differential modifications between conditions. Group names should be alphanumeric and without spaces. The underlying models take the first group alphabetically as the reference level, and the second group alphabetically as the treatment level.

An example samplesheet is shown below:

```
name,group,path_dorado,path_m6anet
sample1,group1,/path/to/dorado/reads.bam,
```

<table>
<thead>
<tr><th>name</th><th>group</th><th>path_dorado</th><th>path_m6anet</th></tr>
</thead>
<tr><td>sample1</td><td>group1</td><td>/path/to/dorado/reads.bam</td><td><em>null</em></td></tr>
</table>
