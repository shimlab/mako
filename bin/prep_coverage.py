#!/usr/bin/env python3

import argparse
import csv
import sys
import duckdb
import pandas as pd
import pysam
from collections import Counter
from datetime import datetime


def main(args):
    conn = duckdb.connect(args.dorado_db)
    conn.execute("""
        CREATE TABLE coverage (
            transcript_id VARCHAR,
            sample VARCHAR,
            "group" VARCHAR,
            count BIGINT
        )
    """)

    counts = Counter()

    with open(args.samplesheet) as f:
        for row in csv.DictReader(f):
            if not row['path_dorado']:
                continue
            sample_name = row['name']
            group = row['group']
            bam_path = row['path_dorado']

            print(f"{datetime.now()} Processing {bam_path} (sample: {sample_name})", file=sys.stderr)
            sys.stderr.flush()

            with pysam.AlignmentFile(bam_path, 'rb') as bam:
                for read in bam:
                    if read.is_secondary or read.is_supplementary or read.is_unmapped:
                        continue
                    transcript_id = read.reference_name.partition('|')[0].partition(' ')[0]
                    counts[(transcript_id, sample_name, group)] += 1

    df = pd.DataFrame(
        [(t, s, g, c) for (t, s, g), c in counts.items()],
        columns=['transcript_id', 'sample', 'group', 'count']
    )
    conn.register('_counts', df)
    conn.execute('INSERT INTO coverage SELECT transcript_id, sample, "group", count FROM _counts')
    conn.close()
    print(f"{datetime.now()} Done: {args.dorado_db}", file=sys.stderr)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--samplesheet', required=True, help='Pipeline samplesheet CSV')
    parser.add_argument('--dorado_db',    required=True, help='Output DuckDB path for Dorado')
    main(parser.parse_args())
