process BAM_TO_FASTQ {
    tag "${sample_name}"
    label 'single_cpu'

    input:
    tuple val(sample_name), val(group), path(bam)

    output:
    tuple val(sample_name), val(group), path("sample.fastq")

    script:
    """
    samtools fastq ${bam} > sample.fastq
    """

    stub:
    """
    touch sample.fastq
    """
}

process M6ANET {
    tag "${sample_name}"
    label 'gpu'

    input:
    tuple val(sample_name), val(group), path(fastq), path(bam), path(fast5), path(transcript_fasta)

    output:
    tuple val(sample_name), val(group), path("output")

    script:
    """
    PYTHONPATH=./workflow/tools/m6anet python3 -m m6anet.scripts.inference_no_dataprep \
        --fast5 ${fast5} \
        --fastq ${fastq} \
        --bam ${bam} \
        --transcript_fasta ${transcript_fasta} \
        --out_dir output \
        --f5c_path f5c \
        --n_processes 1 \
        --num_iterations 1000
    """

    stub:
    """
    echo "m6anet_output" > output/results.txt
    """
}