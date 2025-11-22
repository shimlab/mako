process PREP_FROM_DORADO {
    label 'high_cpu'
    publishDir "${params.outdir}/modcall/${mod_caller}", mode: params.publish_dir_mode

    input:
    tuple val(mod_caller), path("aggregated_results.csv")

    output:
    tuple val(mod_caller), path("all_sites.duckdb")

    script:
    """
    # Prepare data from Dorado output for differential analysis
    python3 ${projectDir}/scripts/data_prep.py \\
        --input aggregated_results.csv \\
        --method dorado \\
        --threads '${task.cpus}' \\
        --output all_sites.duckdb
    """

    stub:
    """
    cat aggregated_results.csv > all_sites.duckdb
    """
}

process PREP_FROM_M6ANET {
    label 'low_cpu'
    tag "m6anet"

    input:
    val step1_results

    output:
    path "sites.tsv"

    script:
    """
    # Prepare data from m6Anet output for differential analysis
    echo "Not implemented yet"
    """

    stub:
    """
    touch sites.tsv
    """
}

process SITE_SELECTION {
    label 'low_cpu'
    publishDir "${params.outdir}/differential/${mod_caller}", mode: params.publish_dir_mode

    input:
    tuple val(mod_caller), path(database)

    output:
    tuple val(mod_caller), path("selected_sites.db"), path(database), path("segments.csv")
    // path "selected_sites.db"
    // path "segments.csv"

    script:
    """
    # Select sites for differential analysis based on the prepared data
    python3 ${projectDir}/scripts/select_sites.py \\
        --in-db ${database} \\
        --out-db selected_sites.db \\
        --segments segments.csv \\
        --batch-size 300000 \\
        --output-file segments.csv
    """

    stub:
    """
    echo "start,end" > segments.csv
    echo "0,1000" >> segments.csv
    echo "1001,2000" >> segments.csv
    echo "2001,3000" >> segments.csv
    echo "3001,4000" >> segments.csv

    touch selected_sites.db
    """
}
