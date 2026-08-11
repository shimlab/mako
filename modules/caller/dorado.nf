
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

process EXTRACT_MODIFICATIONS {
    tag "${sample_name}"
    label 'medium_cpu'
    publishDir "${params.outdir}/modcall/${sample_name}", mode: params.publish_dir_mode

    input:
    tuple val(sample_name), val(group), path("sorted.bam"), path("sorted.bam.bai")
    path ref

    output:
    tuple val(sample_name), val(group), path("modifications_${sample_name}.tsv.gz")

    script:
    """
    # Extract command gets read-level modification information
    extract_from_modbam.py sorted.bam --threads ${task.cpus} > reads_unsorted.tsv

    # Sort reads.tsv by column 4 (chrom), then column 3 (ref_position)
    (head -n 1 reads_unsorted.tsv && \
     tail -n +2 reads_unsorted.tsv | sort -k4,4 -k3,3n --parallel ${task.cpus}) | gzip > modifications_${sample_name}.tsv.gz

    # delete unsorted file to save space
    rm reads_unsorted.tsv
    """

    stub:
    """
    touch modifications_${sample_name}.tsv.gz
    """
}