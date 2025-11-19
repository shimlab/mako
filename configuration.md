---
title: Configuration
layout: default
nav_order: 3
---

# Parameters
{% include parameters.html %}

# Samplesheet
The samplesheet is a CSV file which contains information about the samples to be analysed in the pipeline. It should have the following columns. **A header is required**. Optional columns should be left empty.
* `name`: a unique name for each sample
* `group`: the experimental group or condition for each sample
* `path_dorado`: (optional) path to pre-basecalled Dorado modification data for each sample
* `path_m6anet`: (optional) path to pre-basecalled m6Anet modification data for each sample
* `path_pod5`: (optional) path to raw POD5

If you call modifications using Dorado, you must provide either `path_dorado` or `path_pod5` for each sample. If you call modifications using m6Anet, you must provide either `path_m6anet` or `path_pod5` for each sample.

Two groups should be provided to call differential modifications between conditions. Group names should be alphanumeric and without spaces. The underlying model take the first group alphabetically as the reference level, and the second group alphabetically as the treatment level.

An example samplesheet is shown below:
```
name,group,path_dorado,path_m6anet,path_pod5
sample1,group1,,,pod5_path
```
<table>
<thead>
<tr><th>name</th><th>group</th><th>path_dorado</th><th>path_m6anet</th><th>path_pod5</th></tr>
</thead>
<tr><td>sample1</td><td>group1</td><td></td><td></td><td>pod5_path</td></tr>
</table>