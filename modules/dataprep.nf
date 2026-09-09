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
    path("sites.duckdb"), emit: sites_db
    path("segments.csv"), emit: segments, optional: true

    script:
    """
    # Select sites for differential analysis based on the prepared data
    select_sites.py \\
        --in-db ${database} \\
        --out-db sites.duckdb \\
        --min-reads-per-sample ${params.min_reads_per_sample} \\
        --modification-threshold ${params.mod_threshold} \\
        --segments segments.csv \\
        ${params.method == 'dss' ? '--pooled' : '--batch-size 75000'} \\
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

process EXTRACT_GTF_FEATURES {
    label 'low_cpu'
    publishDir "${params.outdir}/db", mode: params.publish_dir_mode

    input:
    path(gtf)

    output:
    path("gtf_features.duckdb")

    script:
    """
    duckdb gtf_features.duckdb <<'EOF'
CREATE OR REPLACE VIEW gtf AS
SELECT * FROM read_csv(
    '${gtf}',
    delim = '\t',
    comment = '#',
    header = false,
    quote = '',
    names = ['chromosome', 'source', 'type', 'start', 'end',
             'score', 'strand', 'phase', 'attributes'],
    types = {'start': 'INTEGER', 'end': 'INTEGER'}
);

CREATE TABLE features AS
SELECT chromosome, type, start, "end", strand,
       regexp_extract(attributes, 'transcript_id "([^"]+)"', 1) AS transcript_id
FROM gtf
WHERE type NOT IN ('gene', 'transcript');

CREATE TABLE transcripts AS
SELECT DISTINCT
    regexp_extract(attributes, 'gene_id "([^"]+)"', 1) AS gene_id,
    regexp_extract(attributes, 'transcript_id "([^"]+)"', 1) AS transcript_id,
    regexp_extract(attributes, 'gene_type "([^"]+)"', 1) AS gene_type,
    regexp_extract(attributes, 'gene_name "([^"]+)"', 1) AS gene_name
FROM gtf
WHERE "type" = 'transcript';

CREATE TABLE regions AS
WITH bounds AS (
    SELECT
        transcript_id,
        MIN(start) FILTER (WHERE lower(type) = 'cds')     AS cds_left,
        MAX("end") FILTER (WHERE lower(type) = 'cds')     AS cds_right,
        COUNT(*)   FILTER (WHERE lower(type) = 'cds') > 0 AS has_cds,
        ANY_VALUE(strand)                                 AS tx_strand
    FROM features
    GROUP BY transcript_id
)
SELECT
    f.chromosome, f.start, f."end", f.strand, f.transcript_id,
    CASE
        WHEN NOT b.has_cds           THEN 'exon'
        WHEN lower(f.type) = 'cds'   THEN 'CDS'
        WHEN f."end" <= b.cds_left   THEN IF(b.tx_strand = '+', '5UTR', '3UTR')
        WHEN f.start  >= b.cds_right THEN IF(b.tx_strand = '+', '3UTR', '5UTR')
    END AS type
FROM features f
JOIN bounds b USING (transcript_id)
WHERE (NOT b.has_cds AND lower(f.type) = 'exon')
   OR (b.has_cds AND (lower(f.type) = 'cds' OR lower(f.type) LIKE '%utr%'));

CREATE TABLE regions_cum AS
SELECT
    chromosome, start, "end", strand, transcript_id, type,
    SUM("end" - start + 1) OVER w - ("end" - start + 1)            AS cum_start,
    SUM("end" - start + 1) OVER w                                  AS cum_end,
    SUM("end" - start + 1) OVER (PARTITION BY transcript_id, type) AS total_length
FROM regions
WHERE type IN ('5UTR', 'CDS', '3UTR')
WINDOW w AS (
    PARTITION BY transcript_id, type
    ORDER BY CASE WHEN strand = '-' THEN -start ELSE start END
    ROWS UNBOUNDED PRECEDING
);

EOF
    """

    stub:
    """
    touch gtf_features.duckdb
    """
}
