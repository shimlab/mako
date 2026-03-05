#!/usr/bin/env python3

import argparse
import duckdb
import pandas as pd
import sys
from datetime import datetime

"""
Data preparation script for differential RNA modification analysis.

Author: Sophie Wharrie, Oliver Cheng
Date: 2025
Description: Script to load and prepare read-level RNA modification probabilities
             into SQLite databases for efficient filtering and analysis.
"""


def dorado_data_prep(file_info_list, args):
    """
    Load data from TSV files into a DuckDB database using UNION ALL approach.
    Args:
        file_info_list (list): List of dicts with keys: file_path, sample_name, group_name.
        args: Command line arguments
    """

    conn = duckdb.connect(args.database)

    # set to around 50% of system process memory (64GB when running with Nextflow)
    # in order to avoid being killed:
    # https://duckdb.org/docs/stable/guides/troubleshooting/oom_errors.html
    conn.execute("SET memory_limit = '32GB';")
    conn.execute(f"SET threads TO {args.threads};")

    print(f"Using {args.threads} threads for data preparation.", file=sys.stderr)
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
                NOT (mod_qual <= {args.probability_bound_lower} OR mod_qual >= {args.probability_bound_upper}) as ignored
            FROM read_csv('{file_path}', delim='\t')
        """)

        # removed ORDER BY chrom, ref_position; since reads.tsv should now be already sorted

    print(datetime.now(), "Creating summary table...", file=sys.stderr)


    print(
        f"{datetime.now()} Successfully loaded {len(file_info_list)} files into {args.database}",
        file=sys.stderr,
    )

    conn.close()



def m6anet_data_prep(csv_file, args):
    """
    Load data from a CSV file into a SQLite database for efficient filtering and create a summary table of the sites.
    Args:
        args: Command line arguments
    """

    conn = duckdb.connect(args.database)

    # set to around 50% of system process memory (64GB when running with Nextflow)
    # in order to avoid being killed:
    # https://duckdb.org/docs/stable/guides/troubleshooting/oom_errors.html
    conn.execute("SET memory_limit = '32GB';")
    conn.execute(f"SET threads TO {args.threads};")

    conn.execute(
        "CREATE TABLE reads (sample_name VARCHAR, group_name VARCHAR, rname VARCHAR, transcript_position INTEGER, probability_modified FLOAT, modification_type VARCHAR, ignored BOOLEAN);"
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
                transcript_id as rname,
                transcript_position as transcript_position,
                probability_modified as probability_modified,
                'm6a' as modification_type,
                NOT (probability_modified <= {args.probability_bound_lower} OR probability_modified >= {args.probability_bound_upper}) as ignored
            FROM read_csv('{file_path}', delim=',', header=true)
        """)

    print(datetime.now(), "Creating summary table...", file=sys.stderr)


    print(
        f"{datetime.now()} Successfully loaded {len(file_info_list)} files into {args.database}",
        file=sys.stderr,
    )

    conn.close()





if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Preparing data for differential RNA modification analysis."
    )
    parser.add_argument(
        "--input",
        help="CSV file containing samples list in order [sample_name, group, file_path] with header, or DuckDB path for --method segments",
    )
    parser.add_argument(
        "--method",
        choices=["dorado", "m6anet"],
        help="Method used for modification calling.",
    )
    parser.add_argument(
        "--threads",
        default=16,
        type=int,
        help="Number of threads to use for data preparation (default: 16)",
    )
    parser.add_argument(
        "--batch-size",
        default=75000,
        type=int,
        help="Number of sites per segment (default: 75000)",
    )
    parser.add_argument("--database", help="Output database path")
    parser.add_argument("--probability-bound", type=str, help="Filter out reads with probabilities between these bounds, in the format lower,upper (e.g. 0.2,0.8)")

    args = parser.parse_args()

    if args.probability_bound:
        bounds = args.probability_bound.split(",")
        if len(bounds) != 2:
            print("Error: --probability-bound must be in the format lower,upper (e.g. 0.2,0.8)", file=sys.stderr)
            sys.exit(1)
        try:
            args.probability_bound_lower = float(bounds[0])
            args.probability_bound_upper = float(bounds[1])
        except ValueError:
            print("Error: --probability-bound values must be valid floats (e.g. 0.2,0.8)", file=sys.stderr)
            sys.exit(1)
    else:
        # will effectively disable the bounds
        args.probability_bound_lower = 1
        args.probability_bound_upper = 0

    file_info_list = pd.read_csv(args.input, header=0).to_dict(orient="records")
    if args.method.lower() == "dorado":
        dorado_data_prep(file_info_list, args)

    elif args.method.lower() == "m6anet":
        m6anet_data_prep(file_info_list, args)
