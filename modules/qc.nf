process FLAGSTAT {
    publishDir "${params.outdir}/basecall/${sample_name}", mode: params.publish_dir_mode
    label 'single_cpu'

    input:
    tuple val(sample_name), path(bam)
    
    output:
    tuple val(sample_name), path("${sample_name}.flagstat.txt")
    
    script:
    """
    samtools flagstat ${bam} > ${sample_name}.flagstat.txt
    """

    stub:
    """
    touch ${sample_name}.flagstat.txt
    """
}

process FASTQC {
    publishDir "${params.outdir}/basecall/${sample_name}", mode: params.publish_dir_mode
    label 'single_cpu'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastqc:0.12.1--hdfd78af_0' :
        'quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0' }"

    input:
    tuple val(sample_name), path(bam)
    
    output:
    tuple val(sample_name), path("*_fastqc.{html,zip}")
    
    script:
    """
    fastqc ${bam} --memory 8000
    """

    stub:
    """
    touch ${sample_name}_fastqc.html
    touch ${sample_name}_fastqc.zip
    """

}

process NANOPLOT {
    publishDir "${params.outdir}/basecall/${sample_name}", mode: params.publish_dir_mode
    label 'low_cpu'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/nanoplot:1.43.0--pyhdfd78af_1' :
        'quay.io/biocontainers/nanoplot:1.46.1--pyhdfd78af_0' }"

    input:
    tuple val(sample_name), path("input.bam"), path("input.bam.bai")
    
    output:
    tuple val(sample_name), path("nanoplot")
    
    script:
    """
    NanoPlot -t ${task.cpus} --bam input.bam -o nanoplot
    """

    stub:
    """
    mkdir nanoplot
    touch nanoplot/dummy.txt
    """
}

process NANOCOMP {
    publishDir "${params.outdir}/basecall", mode: params.publish_dir_mode
    label 'low_cpu'


    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/nanocomp:1.24.2--pyhdfd78af_0' :
        'quay.io/biocontainers/nanocomp:1.25.4--pyhdfd78af_0' }"

    input:
    path "sample?.bam"
    path "sample?.bam.bai"

    output:
    path("nanocomp")
    
    script:
    """
    NanoComp -t ${task.cpus} --bam sample*.bam -o nanocomp
    """

    stub:
    """
    mkdir nanocomp
    echo \$(ls) > nanocomp/listing.txt
    touch nanocomp/dummy.txt
    """
}