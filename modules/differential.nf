process CALL_MODEL {
    label 'single_cpu_long'

    input:
    path reads_db
    path sites_db
    tuple val(start), val(end)

    output:
    path "segment_modification_differentials.tsv"

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

    input:
    path "segment*.tsv"

    output:
    path "merged.tsv"

    script:
    """
    awk 'FNR==1 && NR!=1{next} {print}' segment*.tsv > merged.tsv
    """
}
