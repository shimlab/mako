process PREP_COVERAGE {
    label 'single_cpu'
    publishDir "${params.outdir}/db", mode: params.publish_dir_mode

    // TODO: remove this container and bind mount
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/olliecheng/mako_main_singularity:fa5552b' :
        'ghcr.io/olliecheng/mako_main_docker:fa5552b' }"

    

    input:
    path(samplesheet)
    path files

    output:
    path("coverage.dorado.duckdb")

    script:
    """
    prep_coverage.py \\
        --samplesheet ${samplesheet} \\
        --dorado_db coverage.dorado.duckdb
    """

    stub:
    """
    touch coverage.dorado.duckdb
    """
}
