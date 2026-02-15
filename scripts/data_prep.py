import argparse
import duckdb
import pandas as pd
import json
import sys
from datetime import datetime

"""
Data preparation script for differential RNA modification analysis.

Author: Sophie Wharrie, Oliver Cheng
Date: 2025
Description: Script to load and prepare read-level RNA modification probabilities
             into SQLite databases for efficient filtering and analysis.
"""


def dorado_data_prep(file_info_list, sites_file, threads, interval_a, interval_b):
    """
    Load data from TSV files into a DuckDB database using UNION ALL approach.
    Args:
        file_info_list (list): List of dicts with keys: file_path, sample_name, group_name.
        db_file (str): Path to the DuckDB database file.
    """

    conn = duckdb.connect(sites_file)

    # set to around 50% of system process memory (64GB when running with Nextflow)
    # in order to avoid being killed:
    # https://duckdb.org/docs/stable/guides/troubleshooting/oom_errors.html
    conn.execute("SET memory_limit = '32GB';")
    conn.execute(f"SET threads TO {threads};")

    print(f"Using {threads} threads for data preparation.", file=sys.stderr)
    sys.stderr.flush()

    conn.execute(
        "CREATE TABLE reads (sample_name VARCHAR, group_name VARCHAR, rname VARCHAR, transcript_position INTEGER, probability_modified FLOAT, ignored BOOLEAN);"
    )

    for f in file_info_list:
        print(datetime.now(), "Inserting file:", f["file_path"], file=sys.stderr)
        sys.stderr.flush()

        file_path = f["file_path"]
        sample_name = f["sample_name"]
        group_name = f["group"]

        conn.execute(f"""
            INSERT INTO reads
            SELECT 
                '{sample_name}' as sample_name,
                '{group_name}' as group_name,
                chrom as rname,
                ref_position as transcript_position,
                mod_qual as probability_modified,
                (mod_qual BETWEEN {interval_a} AND {interval_b}) as ignored
            FROM read_csv('{file_path}', delim='\t')
        """)

        # removed ORDER BY chrom, ref_position; since reads.tsv should now be already sorted

    print(datetime.now(), "Creating summary table...", file=sys.stderr)
    sys.stderr.flush()

    conn.execute("""
    CREATE TABLE samples AS
    SELECT 
        rname,
        transcript_position,
        sample_name,
        COUNT(*) AS read_count,
        MAX(probability_modified) as max_prob,
        MIN(probability_modified) as min_prob,
        AVG(probability_modified) as avg_probability_modified,
        var_samp(probability_modified) as variance
    FROM reads
    WHERE ignored = False
    GROUP BY rname, transcript_position, sample_name
    """)

    # conn.execute("""
    # CREATE TABLE reads_summary AS
    # SELECT 
    #   rname,
    #   transcript_position,
    #   COUNT(*) AS read_count,
    #   COUNT(DISTINCT sample_name) AS sample_count,
    #   MAX(probability_modified) as max_prob,
    #   MIN(probability_modified) as min_prob,
    #   AVG(probability_modified) as avg_probability_modified,
    #   var_samp(probability_modified) as variance
    # FROM reads
    # WHERE ignored = False
    # GROUP BY rname, transcript_position
    # """

    conn.close()
    print(
        f"{datetime.now()} Successfully loaded {len(file_info_list)} files into {sites_file}",
        file=sys.stderr,
    )
    sys.stderr.flush()


def m6anet_data_prep(csv_file, db_file, table_name, args):
    """
    Load data from a CSV file into a SQLite database for efficient filtering and create a summary table of the sites.
    Args:
        csv_file (str): Path to the input CSV file.
        db_file (str): Path to the SQLite database file.
        table_name (str): Name of the table to create in the database.
        args: Command line arguments
    """

    # TODO: implement
    pass


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Preparing data for differential RNA modification analysis."
    )
    parser.add_argument(
        "--input",
        help="CSV file containing samples list in order [sample_name, group, file_path] with header",
    )
    parser.add_argument(
        "--method",
        choices=["dorado", "m6Anet"],
        help="Method used for modification calling.",
    )
    parser.add_argument(
        "--threads",
        default=16,
        type=int,
        help="Number of threads to use for data preparation (default: 16)",
    )
    parser.add_argument("--prob-filter-lower-bound", help="Interval A in the filter mod ∉ [a, b]", type=float)
    parser.add_argument("--prob-filter-upper-bound", help="Interval B in the filter mod ∉ [a, b]", type=float)
    parser.add_argument("--output", help="Output sites.tsv path")

    args = parser.parse_args()

    # Parse samples from input CSV
    file_info_list = pd.read_csv(args.input, header=0).to_dict(orient="records")

    if args.method == "dorado":
        dorado_data_prep(file_info_list, args.output, args.threads, args.prob_filter_lower_bound, args.prob_filter_upper_bound)

    elif args.method == "m6Anet":
        m6anet_data_prep(file_info_list, args.output)
