#!/usr/bin/env Rscript

library(tidyverse)
library(duckdb)
library(GenomicFeatures)
library(txdbmaker)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) {
  stop("Usage: Rscript script.R <duckdb_path> <gtf_path>")
}

db_path <- args[1]
gtf_path <- args[2]


txdb <- txdbmaker::makeTxDbFromGFF(gtf_path)
exons <- exonsBy(txdb, by = c("tx", "gene"), use.names = TRUE)

conn <- dbConnect(duckdb(), dbdir = db_path, read_only = TRUE)
df <- dbGetQuery(conn, "SELECT * FROM sites")
dbDisconnect(conn)

# extract transcript_id from rname
df$transcript_id = str_split_i(df$rname, "[| ]", 1) 

tx_coords <- GRanges(
  seqnames = df$transcript_id,
  ranges = IRanges(
    start = df$transcript_position + 1,
    end   = df$transcript_position + 1
  )
)

# perform mapping and assignment of chrom, pos
genomic_coords <- mapFromTranscripts(tx_coords, exons)

df$chr     <- NA_character_
df$chr_position <- NA_integer_
df$chr[genomic_coords$xHits]     <- as.character(seqnames(genomic_coords))
df$chr_position[genomic_coords$xHits] <- start(genomic_coords)

# reorder columns
df <- df %>% dplyr::select(transcript_id, transcript_position, chr, chr_position, rname, everything())

conn_out <- dbConnect(duckdb(), dbdir = db_path, read_only = FALSE)
dbWriteTable(conn_out, "sites", df, overwrite = TRUE)
dbDisconnect(conn_out)