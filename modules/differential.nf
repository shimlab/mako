process CALL_MODEL {
    label 'single_cpu_long'
    publishDir "${params.outdir}/differential/${mod_caller}", mode: params.publish_dir_mode

    input:
    tuple val(differential_model), val(mod_caller), path(sites_db), path(reads_db), val(start), val(end)

    output:
    tuple val(differential_model), val(mod_caller), path("segments/${differential_model}_${start}_to_${end}.parquet")

    script:
    """
    mkdir segments

    Rscript ${projectDir}/scripts/run_model.R \\
        --sites-database ${sites_db} \\
        --reads-database ${reads_db} \\
        --start ${start} \\
        --end ${end} \\
        --model ${differential_model} \\
        --output segments/${differential_model}_${start}_to_${end}.parquet \\
    """

    stub:
    """
    mkdir segments
    echo "${start} to ${end}" > segments/${differential_model}_${start}_to_${end}.parquet
    """
}

process MERGE_SEGMENTS {
    label 'low_cpu'
    publishDir "${params.outdir}/differential/${mod_caller}", mode: params.publish_dir_mode

    // TODO: remove and use standard container once testing is complete
    container "${ workflow.containerEngine == 'singularity' ?
    'oras://ghcr.io/olliecheng/mako_main_singularity:be76da4' :
    'ghcr.io/olliecheng/mako_main_docker:be76da4' }"

    input:
    tuple val(differential_model), val(mod_caller), path("segment*.parquet")

    output:
    tuple val(differential_model), val(mod_caller), path("differential_sites_${differential_model}.duckdb")

    script:
    """
    duckdb differential_sites_${differential_model}.duckdb \
        "SET memory_limit='28GB'; CREATE TABLE sites AS SELECT * FROM 'segment*.parquet' ORDER BY transcript_id, transcript_position"
    """

    stub:
    """
    echo "test" > differential_sites_${differential_model}.duckdb
    """
}
