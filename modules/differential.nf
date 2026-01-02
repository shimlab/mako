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
    label 'local'
    publishDir "${params.outdir}/differential/${mod_caller}", mode: params.publish_dir_mode

    input:
    tuple val(differential_model), val(mod_caller), path("segment*.parquet")

    output:
    tuple val(differential_model), val(mod_caller), path("differential_sites_${differential_model}.duckdb")

    script:
    """
    duckdb differential_sites_${differential_model}.duckdb \
        "CREATE TABLE sites AS SELECT * FROM 'segment*.parquet' ORDER BY transcript_id, transcript_position"
    """

    stub:
    """
    echo "test" > differential_sites_${differential_model}.duckdb
    """
}
