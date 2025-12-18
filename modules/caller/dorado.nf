process DORADO_BASECALL_ALIGN {
    tag "${sample_name}"
    label 'gpu'
    publishDir "${params.outdir}/basecall/${sample_name}", mode: params.publish_dir_mode

    container "nanoporetech/dorado:shae9327ad17e023b76e4d27cf287b6b9d3a271092b"

    input:
    tuple val(sample_name), val(group), path(path_pod5), val(path_temp_pod5)
    path ref

    output:
    tuple val(sample_name), val(group), path('basecalled.bam')

    script:
    def pod5_file = path_pod5.name != 'NO_FILE' ? path_pod5 : path_temp_pod5

    """
    # Combined basecalling, alignment to reference transcriptome and modification detection with dorado
    dorado basecaller hac,m6A_DRACH ${pod5_file} \\
        --reference ${ref} \\
        --mm2-opts "-x map-ont" \\
        --modified-bases-threshold 0 > basecalled.bam
    """

    stub:
    """
    sleep 5
    touch basecalled.bam
    """
}

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
