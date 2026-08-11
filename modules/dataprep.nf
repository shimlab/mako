// NOTE: data_prep.py's own --method flag (modbam/table) refers to the *input data format*,
// unrelated to the Nextflow-level params.method (the statistical differential-calling model).
process PREP_FROM_MODBAM {
    label 'medium_cpu'
    publishDir "${params.outdir}/db", mode: params.publish_dir_mode

    input:
    path("aggregated_results.csv")
    path 'files'

    output:
    path("reads.duckdb")

    script:
    """
    # Prepare data from modbam output for differential analysis
    data_prep.py \\
        --input aggregated_results.csv \\
        --method modbam \\
        --batch-size 75000 \\
        --threads '${task.cpus}' \\
        --probability-bound '${params.mod_filter}' \\
        --database reads.duckdb
    """

    stub:
    """
    echo "reads.duckdb" > reads.duckdb
    """
}

process PREP_FROM_TABLE {
    label 'medium_cpu'
    publishDir "${params.outdir}/db", mode: params.publish_dir_mode

    input:
    path("aggregated_results.csv")
    path 'files'

    output:
    path("reads.duckdb")

    script:
    """
    # Prepare data from table output for differential analysis
    data_prep.py \\
        --input aggregated_results.csv \\
        --method table \\
        --batch-size 75000 \\
        --threads '${task.cpus}' \\
        --probability-bound '${params.mod_filter}' \\
        --database reads.duckdb
    """

    stub:
    """
    echo "reads.duckdb" > reads.duckdb
    """
}

process SITE_SELECTION {
    label 'low_cpu'
    publishDir "${params.outdir}/differential", mode: params.publish_dir_mode

    input:
    path(database)
    path(gtf)

    output:
    tuple path("sites.duckdb"), path("segments.csv")

    script:
    """
    # Select sites for differential analysis based on the prepared data
    select_sites.py \\
        --in-db ${database} \\
        --out-db sites.duckdb \\
        --min-reads-per-sample ${params.min_reads_per_sample} \\
        --segments segments.csv \\
        --batch-size 75000 \\
        --output-file segments.csv
    
    map_to_genome.R sites.duckdb ${gtf}
    """

    stub:
    """
    echo "start,end" > segments.csv
    echo "0,1000" >> segments.csv
    echo "1001,2000" >> segments.csv
    echo "2001,3000" >> segments.csv
    echo "3001,4000" >> segments.csv

    touch sites.duckdb
    """
}
