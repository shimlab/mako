process PREP_FROM_DORADO {
    label 'high_cpu'
    publishDir "${params.outdir}/modcall/${mod_caller}", mode: params.publish_dir_mode

    input:
    tuple val(mod_caller), path("aggregated_results.csv")
    path 'files'

    output:
    tuple val(mod_caller), path("all_sites.duckdb")

    script:
    """
    # Prepare data from Dorado output for differential analysis
    data_prep.py \\
        --input aggregated_results.csv \\
        --method dorado \\
        --batch-size 75000 \\
        --threads '${task.cpus}' \\
        --probability-bound '${params.mod_filter_dorado}' \\
        --database all_sites.duckdb 
    """

    stub:
    """
    echo "all_sites.duckdb" > all_sites.duckdb
    """
}

process PREP_FROM_M6ANET {
    label 'low_cpu'
    tag "m6anet"

    input:
    tuple val(mod_caller), path("aggregated_results.csv")
    path 'files'

    output:
    tuple val(mod_caller), path("all_sites.duckdb")

    script:
    """
    # Prepare data from m6Anet output for differential analysis
    data_prep.py \\
        --input aggregated_results.csv \\
        --method m6anet \\
        --batch-size 75000 \\
        --threads '${task.cpus}' \\
        --probability-bound '${params.mod_filter_m6anet}' \\
        --database all_sites.duckdb 
    """

    stub:
    """
    echo "all_sites.duckdb" > all_sites.duckdb
    """
}

process SITE_SELECTION {
    label 'low_cpu'
    publishDir "${params.outdir}/differential/${mod_caller}", mode: params.publish_dir_mode

    input:
    tuple val(mod_caller), path(database)

    output:
    tuple val(mod_caller), path("selected_sites.db"), path("segments.csv")

    script:
    """
    # Select sites for differential analysis based on the prepared data
    select_sites.py \\
        --in-db ${database} \\
        --out-db selected_sites.db \\
        --min-reads-per-sample ${params.min_reads_per_sample} \\
        --segments segments.csv \\
        --batch-size 75000 \\
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
