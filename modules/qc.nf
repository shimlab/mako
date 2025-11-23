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

    input:
    tuple val(sample_name), path(bam)
    
    output:
    tuple val(sample_name), path("nanoplot")
    
    script:
    """
    NanoPlot -t ${task.cpus} --bam ${bam} -o nanoplot
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

    input:
    path "sample?.bam"
    
    output:
    path("nanocomp")
    
    script:
    """
    NanoComp -t ${task.cpus} --bam sample*.bam -o nanocomp
    """

    stub:
    """
    mkdir nanocomp
    touch nanocomp/dummy.txt
    """
}