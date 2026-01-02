process MODKIT_PILEUP {
    tag "${sample_name}"
    label 'high_cpu'
    publishDir "${params.outdir}/modcall/dorado/${sample_name}", mode: params.publish_dir_mode

    input:
    tuple val(sample_name), val(group), path("sorted.bam"), path("sorted.bam.bai")
    path ref

    output:
    tuple val(sample_name), val(group), path("pileup_${sample_name}.bed.gz"), path("pileup_${sample_name}.bed.gz.tbi")

    script:
    """
    # Create the pileup file (a bedMethyl table of the modification information)
    modkit pileup sorted.bam pileup_${sample_name}.bed \\
        --log-filepath pileup.log \\
        --threads ${task.cpus} \\
        --ref ${ref}
    
    # Compress and index the pileup file
    bgzip pileup_${sample_name}.bed -@ ${task.cpus}

    tabix -p bed pileup_${sample_name}.bed.gz
    # TODO: update htslib to 1.12
    # tabix -p bed -@ ${task.cpus} pileup.bed.gz
    """

    stub:
    """
    touch pileup_${sample_name}.bed.gz
    touch pileup_${sample_name}.bed.gz.tbi
    """
}

process MODKIT_EXTRACT {
    tag "${sample_name}"
    label 'high_cpu'
    publishDir "${params.outdir}/modcall/dorado/${sample_name}", mode: params.publish_dir_mode

    input:
    tuple val(sample_name), val(group), path("sorted.bam"), path("sorted.bam.bai")
    path ref

    output:
    tuple val(sample_name), val(group), path("modifications_${sample_name}.tsv")

    script:
    """
    # Extract command gets read-level modification information
    modkit extract full sorted.bam reads_unsorted.tsv \\
        -t ${task.cpus} \\
        --kmer-size 5 \\
        --mapped-only \\
        --reference ${ref}

    # Sort reads.tsv by column 4 (chrom), then column 3 (ref_position)
    (head -n 1 reads_unsorted.tsv && \
     tail -n +2 reads_unsorted.tsv | sort -k4,4 -k3,3n --parallel ${task.cpus}) > modifications_${sample_name}.tsv
s for 
    # delete unsorted file to save space
    rm reads_unsorted.tsv
    """

    stub:
    """
    touch modifications_${sample_name}.tsv
    """
}
