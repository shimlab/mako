process MODKIT_PILEUP {
    tag "${sample_name}"
    label 'high_cpu'
    publishDir "${params.outdir}/dorado/modcall/${sample_name}", mode: params.publish_dir_mode

    input:
    tuple val(sample_name), val(group), path("sorted.bam"), path("sorted.bam.bai")
    path ref

    output:
    tuple val(sample_name), val(group), path("pileup.bed.gz"), path("pileup.bed.gz.tbi")

    script:
    """
    # Create the pileup file (a bedMethyl table of the modification information)
    modkit pileup sorted.bam pileup.bed \\
        --log-filepath pileup.log \\
        --threads ${task.cpus} \\
        --ref ${ref}
    
    # Compress and index the pileup file
    bgzip pileup.bed -@ ${task.cpus}

    tabix -p bed pileup.bed.gz
    # TODO: update htslib to 1.12
    # tabix -p bed -@ ${task.cpus} pileup.bed.gz
    """

    stub:
    """
    touch pileup.bed.gz
    touch pileup.bed.gz.tbi
    """
}

process MODKIT_EXTRACT {
    tag "${sample_name}"
    label 'high_cpu'
    publishDir "${params.outdir}/dorado/modcall/${sample_name}", mode: params.publish_dir_mode

    input:
    tuple val(sample_name), val(group), path("sorted.bam"), path("sorted.bam.bai")
    path ref

    output:
    tuple val(sample_name), val(group), path("reads.tsv")

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
     tail -n +2 reads_unsorted.tsv | sort -k4,4 -k3,3n --parallel ${task.cpus}) > reads.tsv

    # delete unsorted file to save space
    rm reads_unsorted.tsv
    """

    stub:
    """
    touch reads.tsv
    """
}
