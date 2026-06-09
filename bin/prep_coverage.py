#!/usr/bin/env python3

import argparse
import csv
import sys
import duckdb
import pandas as pd
import pysam
from datetime import datetime

BATCH_SIZE = 75000


def main(args):
    conn = duckdb.connect(args.dorado_db)
    conn.execute("""
        CREATE TABLE coverage (
            read_id VARCHAR,
            transcript_id VARCHAR,
            sample VARCHAR
        )
    """)

    with open(args.samplesheet) as f:
        for row in csv.DictReader(f):
            if not row['path_dorado']:
                continue
            sample_name = row['name']
            bam_path = row['path_dorado']

            print(f"{datetime.now()} Processing {bam_path} (sample: {sample_name})", file=sys.stderr)
            sys.stderr.flush()

            batch = []
            with pysam.AlignmentFile(bam_path, 'rb') as bam:
                for read in bam:
                    if read.is_secondary or read.is_supplementary or read.is_unmapped:
                        continue
                    batch.append({
                        'read_id': read.query_name,
                        'chrom':   read.reference_name,
                        'sample':  sample_name,
                    })
                    if len(batch) >= BATCH_SIZE:
                        _flush(conn, batch)
                        batch = []

            if batch:
                _flush(conn, batch)

    conn.close()
    print(f"{datetime.now()} Done: {args.dorado_db}", file=sys.stderr)


def _flush(conn, batch):
    df = pd.DataFrame(batch)
    conn.register('_batch', df)
    conn.execute("""
        INSERT INTO coverage
        SELECT
            read_id,
            regexp_extract(chrom, '^[^| ]+') AS transcript_id,
            sample
        FROM _batch
    """)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--samplesheet', required=True, help='Pipeline samplesheet CSV')
    parser.add_argument('--dorado_db',    required=True, help='Output DuckDB path for Dorado')
    main(parser.parse_args())
