process CALL_MODEL {
    label 'single_cpu_long'
    publishDir "${params.outdir}/differential/${mod_caller}", mode: params.publish_dir_mode

    input:
    tuple val(differential_model), val(mod_caller), path(sites_db), path(reads_db), val(start), val(end), path(gtf)

    output:
    tuple val(differential_model), val(mod_caller), path("segments/${differential_model}_${start}_to_${end}.parquet")

    script:
    """
    mkdir segments

    run_model.R  \\
        --sites-database ${sites_db} \\
        --reads-database ${reads_db} \\
        --min-reads-per-sample ${params.min_reads_per_sample} \\
        --modification-threshold 0.5 \\
        --start ${start}  \\
        --end ${end}  \\
        --model ${differential_model} \\
        --output segments/${differential_model}_${start}_to_${end}.parquet \\
        --gtf ${gtf}
    """

    stub:
    """
    mkdir segments
    echo "${start} to ${end}" > segments/${differential_model}_${start}_to_${end}.parquet
    """
}

process FDR_CORRECTION {
    label 'low_cpu'
    publishDir "${params.outdir}/differential/${mod_caller}", mode: params.publish_dir_mode

    input:
    tuple val(differential_model), val(mod_caller), path("segment*.parquet")

    output:
    tuple val(differential_model), val(mod_caller), path("${differential_model}_fits.tsv")

    script:
    """
    fdr_correction.py  \
        --alpha 0.05 \
        --output ${differential_model}_fits.tsv \
        segment*.parquet
    """

    stub:
    """
    echo "test" > ${differential_model}_fits.tsv
    """
}
