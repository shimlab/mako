#!/usr/bin/env python3

import argparse
import sys
import duckdb

"""
Data preparation script for differential RNA modification analysis.

Author: Oliver Cheng
Date: 2025
Description: Select RNA modification sites that meet specified criteria
"""


def initialise_db(conn, in_db_path):
    # Attach the input database as a read-only view
    conn.execute(f"ATTACH '{in_db_path}' AS all_sites (READONLY);")


def select_sites(conn, min_reads_per_sample):
    # get number of unique samples in reads_summary
    max_sample_count = conn.execute(
        "SELECT COUNT(DISTINCT sample_name) FROM all_sites.reads"
    ).fetchone()[0]

    print(f"number of unique samples: {max_sample_count}", file=sys.stderr)

    conn.execute(f"""
    CREATE OR REPLACE TABLE site_summary AS
    SELECT 
      rname,
      transcript_position,
      COUNT(*) AS read_count,
      COUNT(DISTINCT sample_name) AS sample_count
    FROM all_sites.samples
    WHERE read_count >= {min_reads_per_sample}
    GROUP BY rname, transcript_position
    """)

    conn.execute(f"""
    CREATE OR REPLACE TABLE selected_sites AS
        SELECT *
        FROM site_summary
        WHERE
            sample_count = {max_sample_count}
        ORDER BY (rname, transcript_position);
    """)

    row_count = conn.execute("SELECT COUNT(*) FROM selected_sites").fetchone()[0]
    return row_count


def main():
    parser = argparse.ArgumentParser(description="Select RNA modification sites.")

    parser.add_argument(
        "--in-db",
        help="Path to the DuckDB database file (read-only)",
    )
    parser.add_argument(
        "--out-db",
        help="Path to the output DuckDB database file (will contain in_db as a view)",
    )
    parser.add_argument(
        "--segments", help="Path to the output CSV file of segment intervals"
    )
    parser.add_argument(
        "--min-reads-per-sample",
        type=int,
        default=5,
        help="Minimum number of reads required per sample at a site (default: 5)",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=400000,
        help="Approximate interval size for each batch (default: 400000)",
    )
    parser.add_argument(
        "--output-file",
        type=str,
        help="File to write segments to, as .csv",
    )

    args = parser.parse_args()

    conn = duckdb.connect(args.out_db)
    initialise_db(conn, args.in_db)

    num_sites = select_sites(conn, args.min_reads_per_sample)
    conn.close()

    print(f"Selected {num_sites} sites meeting criteria", file=sys.stderr)

    # split the sites into chunks based on batch_size
    num_segments = (num_sites + args.batch_size - 1) // args.batch_size

    segments = [
        (i * num_sites // num_segments, (i + 1) * num_sites // num_segments - 1)
        for i in range(num_segments)
    ]

    with open(args.output_file, "w") as f:
        # Output segments in CSV format
        f.write("start,end\n")
        for segment in segments:
            f.write(f"{segment[0]},{segment[1]}\n")


if __name__ == "__main__":
    main()
