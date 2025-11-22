process CALL_MODEL {
    label 'single_cpu_long'
    publishDir "${params.outdir}/differential/${mod_caller}", mode: params.publish_dir_mode

    input:
    tuple val(mod_caller), path(reads_db), path(sites_db), val(start), val(end)

    output:
    tuple val(mod_caller), path("segment_modification_differentials.tsv")

    script:
    """
    echo ${start} ${end}
    Rscript ${projectDir}/scripts/run_model.R \\
        --sites-database ${sites_db} \\
        --reads-database ${reads_db} \\
        --end ${end} \\
        --output segment_modification_differentials.tsv \\
    """

    stub:
    """
    touch segment_modification_differentials.tsv
    """
}


process MERGE_TSVS {
    label 'local'
    publishDir "${params.outdir}/differential/${mod_caller}", mode: params.publish_dir_mode

    input:
    tuple val(mod_caller), path("segment*.tsv")

    output:
    tuple val(mod_caller), path("merged.tsv")

    script:
    """
    awk 'FNR==1 && NR!=1{next} {print}' segment*.tsv > merged.tsv
    """
}
