
process SAMTOOLS_SORT_INDEX {
    tag "${sample_name}"
    label 'low_cpu'
    publishDir "${params.outdir}/basecall/${sample_name}", mode: params.publish_dir_mode

    input:
    tuple val(sample_name), val(group), path(bam)

    output:
    tuple val(sample_name), val(group), path("basecalled_sorted.bam"), path("basecalled_sorted.bam.bai")

    script:
    """
    # Sort and index the bam file (required for downstream analysis with modkit etc)
    samtools sort -o basecalled_sorted.bam ${bam}
    samtools index basecalled_sorted.bam
    """

    stub:
    """
    touch basecalled_sorted.bam
    touch basecalled_sorted.bam.bai
    """
}

process SAMTOOLS_FLAGSTAT {
    tag "${sample_name}"
    label 'local'
    publishDir "${params.outdir}/basecall/${sample_name}", mode: params.publish_dir_mode

    input:
    tuple val(sample_name), path("sorted.bam"), path("sorted.bam.bai")

    output:
    tuple val(sample_name), path("flagstat.txt")

    script:
    """
    # Create statistics on number of reads etc
    samtools flagstat sorted.bam > flagstat.txt
    """

    stub:
    """
    touch flagstat.txt
    """
}
