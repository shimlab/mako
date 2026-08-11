process PREP_COVERAGE {
    label 'single_cpu'
    publishDir "${params.outdir}/db", mode: params.publish_dir_mode

    input:
    path(samplesheet)
    path files

    output:
    path("coverage.duckdb")

    script:
    """
    prep_coverage.py \\
        --samplesheet ${samplesheet} \\
        --input-format ${params.input_format} \\
        --base-dir "${launchDir}" \\
        --output-db coverage.duckdb
    """

    stub:
    """
    touch coverage.duckdb
    """
}
