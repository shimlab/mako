#!/usr/bin/env python3
"""Extract the columns of `modkit extract full --mapped-only` that data_prep.py uses."""

import argparse
import sys
import pysam

p = argparse.ArgumentParser()
p.add_argument("bam")
p.add_argument("--mod-code", default="a", help="modification code to keep (default: a = m6A)")
p.add_argument("--threads", type=int, default=4)
args = p.parse_args()

bam = pysam.AlignmentFile(args.bam, "rb", threads=args.threads)
out = sys.stdout
out.write("chrom\tref_position\tmod_qual\n")

for read in bam:
    if read.is_unmapped or read.is_secondary or read.is_supplementary:
        continue
    mods = read.modified_bases
    if not mods:
        continue
    chrom = read.reference_name
    refpos = read.get_reference_positions(full_length=True)  # indexed by query position
    for (_canonical, _strand, code), calls in mods.items():
        if str(code) != args.mod_code:
            continue
        for qpos, qual in calls:
            rpos = refpos[qpos]
            if rpos is None:  # soft-clipped or inserted — equivalent to --mapped-only
                continue
            out.write(f"{chrom}\t{rpos}\t{(qual + 0.5) / 256}\n")