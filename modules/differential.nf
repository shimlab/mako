process CALL_MODEL {
    label 'single_cpu_long'
    publishDir "${params.outdir}/differential/${mod_caller}", mode: params.publish_dir_mode

    input:
    tuple val(differential_model), val(mod_caller), path(sites_db), path(reads_db), val(start), val(end)

    output:
    tuple val(differential_model), val(mod_caller), path("segments/${differential_model}_${start}_to_${end}.tsv")

    script:
    """
    mkdir segments

    Rscript ${projectDir}/scripts/run_model.R \\
        --sites-database ${sites_db} \\
        --reads-database ${reads_db} \\
        --end ${end} \\
        --model ${differential_model} \\
        --output segments/${differential_model}_${start}_to_${end}.tsv \\
    """

    stub:
    """
    mkdir segments
    echo "${start} to ${end}" > segments/${differential_model}_${start}_to_${end}.tsv
    """
}

process MERGE_TSVS {
    label 'local'
    publishDir "${params.outdir}/differential/${mod_caller}", mode: params.publish_dir_mode

    input:
    tuple val(differential_model), val(mod_caller), path("segment*.tsv")

    output:
    tuple val(differential_model), val(mod_caller), path("differential_sites_${differential_model}.tsv")

    script:
    """
    awk 'FNR==1 && NR!=1{next} {print}' segment*.tsv > differential_sites_${differential_model}.tsv
    """
}
