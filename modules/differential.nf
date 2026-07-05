process CALL_MODEL {
    label 'single_cpu_long'
    publishDir "${params.outdir}/differential", mode: params.publish_dir_mode

    input:
    tuple path(sites_db), path(reads_db), val(start), val(end), path(gtf)

    output:
    path("segments/${start}_to_${end}.parquet")

    script:
    """
    mkdir segments

    run_model.R  \\
        --sites-database ${sites_db} \\
        --reads-database ${reads_db} \\
        --min-reads-per-sample ${params.min_reads_per_sample} \\
        --modification-threshold ${params.mod_threshold} \\
        --start ${start}  \\
        --end ${end}  \\
        --model ${params.method} \\
        --output segments/${start}_to_${end}.parquet \\
        --gtf ${gtf}
    """

    stub:
    """
    mkdir segments
    echo "${start} to ${end}" > segments/${start}_to_${end}.parquet
    """
}

process FDR_CORRECTION {
    label 'low_cpu'
    publishDir "${params.outdir}/differential", mode: params.publish_dir_mode

    input:
    path("segment*.parquet")

    output:
    path("model_calls.tsv")

    script:
    """
    fdr_correction.py  \
        --alpha 0.05 \
        --output model_calls.tsv \
        segment*.parquet
    """

    stub:
    """
    echo "test" > model_calls.tsv
    """
}
