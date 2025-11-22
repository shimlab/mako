process DORADO_BASECALL_ALIGN {
    tag "${sample_name}"
    label 'gpu'

    container "nanoporetech/dorado:shae9327ad17e023b76e4d27cf287b6b9d3a271092b"

    input:
    tuple val(sample_name), val(group), path(path_pod5)
    path ref

    output:
    tuple val(sample_name), val(group), path('basecalled.bam')

    script:
    """
    # Combined basecalling, alignment to reference transcriptome and modification detection with dorado
    dorado basecaller hac,m6A_DRACH ${path_pod5} \\
        --reference ${ref} \\
        --mm2-opts "-x map-ont" \\
        --modified-bases-threshold 0 > basecalled.bam
    """

    stub:
    """
    touch basecalled.bam
    """
}

process SAMTOOLS_SORT_INDEX {
    tag "${sample_name}"
    label 'low_cpu'

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
