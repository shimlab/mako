#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

/*
 * differential-RNA-modification-nanopore
 * Nextflow workflow for differential RNA modification analysis from nanopore data
 */

// IMPORTS
include { SAMTOOLS_SORT_INDEX ; SAMTOOLS_FLAGSTAT } from './modules/caller/dorado'
include { MODKIT_PILEUP ; MODKIT_EXTRACT } from './modules/caller/modkit'
include { PREP_FROM_MODBAM ; PREP_FROM_TABLE ; SITE_SELECTION } from './modules/dataprep'
include { PREP_COVERAGE } from './modules/coverage'
include { CALL_MODEL ; FDR_CORRECTION } from './modules/differential'
include { FLAGSTAT ; FASTQC ; NANOPLOT ; NANOCOMP } from './modules/qc'
include { RETRIEVE_FILE; REMOVE_FILE } from './modules/caller/fs'
include { MAKOVIEW_INIT; MAKOVIEW_CREATE_LAUNCH_SCRIPT } from './modules/makoview'

// SCHEMA VALIDATION
include { validateParameters ; paramsSummaryLog ; paramsHelp } from 'plugin/nf-schema'


// Main workflow
workflow {
    if (!params.testing) {
        // TODO: validate parameters but run the rest of the workflow
        validateParameters()
    }

    // Print workflow info
    log.info("""\
.___  ___.      ___       __  ___   ______   
|   \\/   |     /   \\     |  |/  /  /  __  \\  
|  \\  /  |    /  ^  \\    |  '  /  |  |  |  | 
|  |\\/|  |   /  /_\\  \\   |    <   |  |  |  | 
|  |  |  |  /  _____  \\  |  .  \\  |  `--'  | 
|__|  |__| /__/     \\__\\ |__|\\__\\  \\______/  
                                            
differential RNA modification calling
Shim Lab @ University of Melbourne

docs:   https://shimlab.github.io/mako
    """)

    log.info(paramsSummaryLog(workflow))

    // Read samples file
    samples_ch = channel.fromPath(params.samplesheet)
        .splitCsv(header: true, sep: ',')

    // Check that there are only TWO groups
    samples_ch
        .map { it -> it.group }
        .unique()
        .collect()
        .subscribe { groups ->
            if (groups.size() != 2) {
                // TODO: support multiple groups with pairwise comparisons
                // todo: currently disabled
                println("Exactly two groups are required for differential analysis. Groups: ${groups.join(', ')}")
            }
          }

    if (params.input_format == 'modbam') {
        // ======================
        // modbam workflow
        // ======================
        bam_paths_ch = samples_ch.collect { it ->
            if (!it.path_modbam) {
                error("Samplesheet row for sample '${it.name}' is missing required column 'path_modbam' for input_format='modbam'.")
            }
            file(it.path_modbam)
        }
        PREP_COVERAGE(file(params.samplesheet), bam_paths_ch)

        basecalled_ch = samples_ch
            .map { it ->
                if (!it.path_modbam) {
                    error("Samplesheet row for sample '${it.name}' is missing required column 'path_modbam' for input_format='modbam'.")
                }
                [it.name, it.group, file(it.path_modbam)]
            }

        basecalled_ch
            .map { sample_name, _group, bam -> [sample_name, bam] }
            .set { qc_bam_ch }

        sorted_bam_ch = SAMTOOLS_SORT_INDEX(basecalled_ch)

        // post-basecalling QC
        FLAGSTAT(qc_bam_ch)
        FASTQC(qc_bam_ch)

        NANOPLOT(sorted_bam_ch.map { v -> [v[0], v[2], v[3]] } )
        NANOCOMP(sorted_bam_ch.map { v -> v[2] }.collect(sort: true), sorted_bam_ch.map { v -> v[3] }.collect(sort: true))

        modkit_extract_ch = MODKIT_EXTRACT(sorted_bam_ch, file(params.transcriptome))

        extracted_sites_ch = modkit_extract_ch
            .collectFile(keepHeader: true, skip: 1) {
                it -> ["extracted_sites.csv","sample_name,group,file_path\n${it[0]},${it[1]},${it[2]}\n"]
            }

        reads_ch = PREP_FROM_MODBAM(extracted_sites_ch, bam_paths_ch)
            .first() // convert to value channel

    } else if (params.input_format == 'table') {
        // ======================
        // table workflow
        // ======================
        bam_paths_ch = samples_ch.collect { it ->
            if (!it.path_bam) {
                error("Samplesheet row for sample '${it.name}' is missing required column 'path_bam' for input_format='table'.")
            }
            file(it.path_bam)
        }
        PREP_COVERAGE(file(params.samplesheet), bam_paths_ch)

        basecalled_ch = samples_ch
            .map { it ->
                if (!it.path_bam) {
                    error("Samplesheet row for sample '${it.name}' is missing required column 'path_bam' for input_format='table'.")
                }
                [it.name, it.group, file(it.path_bam)]
            }

        basecalled_ch
            .map { sample_name, _group, bam -> [sample_name, bam] }
            .set { qc_bam_ch }

        sorted_bam_ch = SAMTOOLS_SORT_INDEX(basecalled_ch)

        // post-basecalling QC
        FLAGSTAT(qc_bam_ch)
        FASTQC(qc_bam_ch)

        NANOPLOT(sorted_bam_ch.map { v -> [v[0], v[2], v[3]] } )
        NANOCOMP(sorted_bam_ch.map { v -> v[2] }.collect(sort: true), sorted_bam_ch.map { v -> v[3] }.collect(sort: true))

        // NOTE: no MODKIT_PILEUP/MODKIT_EXTRACT here -- table format supplies its own
        // per-read modification calls via path_csv, it doesn't need BAM-tag extraction.

        tsv_sites_ch = samples_ch
            .collectFile(keepHeader: true, skip: 1) {
                it ->
                    if (!it.path_csv) {
                        error("Samplesheet row for sample '${it.name}' is missing required column 'path_csv' for input_format='table'.")
                    }
                    ["extracted_sites.csv","sample_name,group,file_path\n${it.name},${it.group},${it.path_csv}\n"]
            }

        tsv_paths_ch = samples_ch.collect { it ->
            if (!it.path_csv) {
                error("Samplesheet row for sample '${it.name}' is missing required column 'path_csv' for input_format='table'.")
            }
            file(it.path_csv)
        }
        reads_ch = PREP_FROM_TABLE(tsv_sites_ch, tsv_paths_ch)
            .first() // convert to value channel

    } else {
        error("params.input_format must be one of 'modbam' or 'table', got: ${params.input_format}")
    }

    // ======================
    // differential analysis (caller-agnostic, single-method)
    // ======================

    // site_selection_ch: [selected_sites.db, segments.csv]
    site_selection_ch = SITE_SELECTION(reads_ch, file(params.gtf))

    segments_ch = reads_ch
        .combine(site_selection_ch)
        .flatMap { reads_db, sites_db, segments_file ->
            def seg = segments_file.splitCsv(header: true, sep: ',')
            seg.collect { row -> [sites_db, reads_db, row.start, row.end, file(params.gtf)] }
        }

    diff_ch = CALL_MODEL(segments_ch).collect()

    completed_ch = FDR_CORRECTION(diff_ch)

    // initialise Makoview index
    makoview_init_results_ch = MAKOVIEW_INIT(file(params.gtf), file(params.genome))

    MAKOVIEW_CREATE_LAUNCH_SCRIPT(
        makoview_init_results_ch.gtf_file,
        makoview_init_results_ch.genome_file,
        completed_ch
    )

}

