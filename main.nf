#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

/*
 * differential-RNA-modification-nanopore
 * Nextflow workflow for differential RNA modification analysis from nanopore data
 */

// IMPORTS
include { SAMTOOLS_SORT_INDEX ; SAMTOOLS_FLAGSTAT } from './modules/caller/dorado'
include { MODKIT_PILEUP ; MODKIT_EXTRACT } from './modules/caller/modkit'
include { PREP_FROM_DORADO ; PREP_FROM_M6ANET ; SITE_SELECTION } from './modules/dataprep'
include { CALL_MODEL ; FDR_CORRECTION } from './modules/differential'
include { FLAGSTAT ; FASTQC ; NANOPLOT ; NANOCOMP } from './modules/qc'
include { RETRIEVE_FILE; REMOVE_FILE } from './modules/caller/fs'

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

    // parse differential model
    differential_models_ch = channel.from(params.differential_model.tokenize(",")).map { it -> it.trim() }


    // ======================
    // dorado workflow
    // ======================
    dorado_basecalled_ch = samples_ch
        .filter { it -> it.path_dorado }
        .map { it -> [it.name, it.group, file(it.path_dorado)] }

    dorado_basecalled_ch
        .map { sample_name, _group, bam -> [sample_name, bam] }
        .set { qc_bam_ch }

    sorted_bam_ch = SAMTOOLS_SORT_INDEX(dorado_basecalled_ch)

    // post-basecalling QC
    FLAGSTAT(qc_bam_ch)
    FASTQC(qc_bam_ch)

    NANOPLOT(sorted_bam_ch.map { v -> [v[0], v[2], v[3]] } )
    NANOCOMP(sorted_bam_ch.map { v -> v[2] }.collect(sort: true), sorted_bam_ch.map { v -> v[3] }.collect(sort: true))

    MODKIT_PILEUP(sorted_bam_ch, file(params.transcriptome))
    modkit_extract_ch = MODKIT_EXTRACT(sorted_bam_ch, file(params.transcriptome))

    dorado_sites_ch = modkit_extract_ch
        .collectFile(keepHeader: true, skip: 1) {
            it -> ["dorado_extracted_sites.csv","sample_name,group,file_path\n${it[0]},${it[1]},${it[2]}\n"]
        }
    
    dorado_paths_ch = samples_ch.filter {it -> it.path_dorado }.collect { it -> file(it.path_dorado) }
    dorado_reads_ch = PREP_FROM_DORADO(dorado_sites_ch.map { it -> ["dorado", it] }, dorado_paths_ch)
        .first() // convert to value channel


    // ======================
    // m6Anet workflow
    // ======================
    m6anet_sites_ch = samples_ch
        .filter { it -> it.path_m6anet }
        .collectFile(keepHeader: true, skip: 1) {
            it -> ["m6anet_extracted_sites.csv","sample_name,group,file_path\n${it.name},${it.group},${it.path_m6anet}\n"]
        }

    m6anet_paths_ch = samples_ch.filter {it -> it.path_m6anet }.collect { it -> file(it.path_m6anet) }
    m6anet_reads_ch = PREP_FROM_M6ANET(m6anet_sites_ch.map { it -> ["m6anet", it] }, m6anet_paths_ch)
        .first() // convert to value channel


    // ======================
    // differential analysis
    // ======================

    // reads_ch: [mod_caller, reads_db]
    reads_ch = dorado_reads_ch.mix(m6anet_reads_ch)

    // site_selection_ch: [mod_caller, selected_sites.db, segments.csv]
    site_selection_ch = SITE_SELECTION(reads_ch)

    segments_ch = reads_ch
        .join(site_selection_ch, by: 0)
        .flatMap { mod_caller, reads_db, sites_db, segments_file ->
            def seg = segments_file.splitCsv(header: true, sep: ',')
            seg.collect { row -> [mod_caller, sites_db, reads_db, row.start, row.end, file(params.gtf)] }
        }

    // CALL_MODEL produces [diff_caller, mod_caller, segment];
    //   groupTuple expects [[diff_caller, mod_caller], [segment]]
    //   to produce [[diff_caller, mod_caller], [segment1, segment2, ...]]
    //   so we map and unmap accordingly
    diff_ch = CALL_MODEL(differential_models_ch.combine(segments_ch))
        .map { it -> [[it[0], it[1]], it[2]] }
        .groupTuple()
        .map { it -> [it[0][0], it[0][1], it[1]] }

    FDR_CORRECTION(diff_ch)
}
