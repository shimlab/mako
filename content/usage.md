---
title: Usage
hide:
  - navigation
---

!!! warning "Work in progress"
    **mako** is in active development and not all features are supported yet. Key features that need to be implemented:

    - Certain QC visualisations, such as the metagene plot

    Bug reports are highly welcome and we would greatly appreciate they be sent to our [GitHub Issues tracker](https://github.com/shimlab/mako/issues).

## Samplesheet

The samplesheet is a CSV file which contains information about the samples to be analysed in the pipeline. **A header is required**.

=== "modBAM input"
    This is suitable for modifications analysed by **Dorado**.
    
    ```csv title="samplesheet.csv"
    name,group,path_modbam
    sample1,group1,/base_and_modcalled/reads1.bam
    sample2,group1,/base_and_modcalled/reads2.bam
    sample3,group1,/base_and_modcalled/reads3.bam
    sample4,group2,/base_and_modcalled/reads4.bam
    sample5,group2,/base_and_modcalled/reads5.bam
    sample6,group2,/base_and_modcalled/reads6.bam
    ```

    - `name`: a unique name for each sample
    - `group`: the experimental group or condition for each sample
    - `path_modbam`: path to pre-basecalled Dorado modification data for each sample.  
    The file should be a .bam file in 'modbam' format i.e. with tags `MM` and `ML`. See the [Dorado documentation](https://software-docs.nanoporetech.com/dorado/latest/basecaller/mods/) for more information.

    Start Mako:
    ```bash title="bash"
    export REFERENCE_GENOME=/ref/GRCh38.p14.genome.fa \
           REFERENCE_TXOME=/ref/gencode.v50.transcripts.fa \
           REFERENCE_GTF=/ref/gencode.v50.annotation.gtf \
           OUTDIR=results

    # run Mako
    nextflow run main.nf \
      -profile singularity \
      --samplesheet samplesheet.csv \
      --dataset_name test_dataset \
      --outdir $OUTDIR \
      --input_format modbam \
      --mod_threshold 0.5 \
      --genome $REFERENCE_GENOME \
      --transcriptome $REFERENCE_TXOME \
      --gtf $REFERENCE_GTF

    # launch Makoview
    ./$OUTDIR/makoview/launch_makoview.sh
    ```

=== "BAM + CSV input"
    This is suitable for modifications analysed by **m6Anet**.
    
    ```csv title="samplesheet.csv"
    name,group,path_bam,path_csv
    sample1,group1,/basecalled/reads1.bam,/m6anet_out_1/data.indiv_proba.csv
    sample2,group1,/basecalled/reads2.bam,/m6anet_out_2/data.indiv_proba.csv
    sample3,group1,/basecalled/reads3.bam,/m6anet_out_3/data.indiv_proba.csv
    sample4,group2,/basecalled/reads4.bam,/m6anet_out_4/data.indiv_proba.csv
    sample5,group2,/basecalled/reads5.bam,/m6anet_out_5/data.indiv_proba.csv
    sample6,group2,/basecalled/reads6.bam,/m6anet_out_6/data.indiv_proba.csv
    ```

    - `name`: a unique name for each sample
    - `group`: the experimental group or condition for each sample
    - `path_bam`: path to pre-basecalled and aligned reads in BAM format
    - `path_csv`: path to a CSV table containing rows with each analysed modification probability.
      If using m6Anet, this file is `data.indiv_proba.csv`. The file must have columns `transcript_id, transcript_position, read_index, probability_modified`.

    Start Mako:
    ```bash title="bash"
    export REFERENCE_GENOME=/ref/GRCh38.p14.genome.fa \
           REFERENCE_TXOME=/ref/gencode.v50.transcripts.fa \
           REFERENCE_GTF=/ref/gencode.v50.annotation.gtf \
           OUTDIR=results

    # run Mako
    nextflow run main.nf \
        -profile singularity \
        --samplesheet samplesheet.csv \
        --dataset_name test_dataset \
        --outdir $OUTDIR \
        --input_format table \
        --mod_threshold 0.033379376 \
        --genome $REFERENCE_GENOME \
        --transcriptome $REFERENCE_TXOME \
        --gtf $REFERENCE_GTF

    # launch Makoview
    ./$OUTDIR/makoview/launch_makoview.sh
    ```
    !!! warning "Modification thresholds for m6Anet"
        The [m6Anet documentation](https://github.com/GoekeLab/m6anet/blob/590ec277cb48d61774f0872395099e466022e810/README.md) suggests to use 0.033379376 as the threshold for individual reads to be called as modified. Always consult your tool of choice to determine this value.


Two groups should be provided to identify differential modifications between conditions. Group names should be alphanumeric and without spaces. The underlying models take the first group alphabetically as the reference level, and the second group alphabetically as the treatment level.


## Parameters

!!! note
    If your institution has an [nf-core configuration](https://nf-co.re/configs/) available, you can access it through `-profile` i.e. `-profile wehi` to use the WEHI Milton HPC. See [Execution Profiles](deployment.md#execution-profiles) for more.

    Dependencies for Mako are distributed as container images for Docker and Singularity (Apptainer). If not using an nf-core configuration, run Mako using `-profile docker` or `-profile singularity`.

--8<-- "includes/parameters.html"