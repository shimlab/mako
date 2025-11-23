#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

/*
 * differential-RNA-modification-nanopore
 * Nextflow workflow for differential RNA modification analysis from nanopore data
 */

// IMPORTS
include { DORADO_BASECALL_ALIGN ; SAMTOOLS_SORT_INDEX ; SAMTOOLS_FLAGSTAT } from './modules/caller/dorado'
include { MODKIT_PILEUP ; MODKIT_EXTRACT } from './modules/caller/modkit'
include { M6ANET_DETECT } from './modules/caller/m6anet'
include { PREP_FROM_DORADO ; PREP_FROM_M6ANET ; SITE_SELECTION } from './modules/dataprep'
include { CALL_MODEL ; MERGE_TSVS } from './modules/differential'
include { FLAGSTAT ; FASTQC ; NANOPLOT ; NANOCOMP } from './modules/qc'

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
    samples_ch = Channel.fromPath(params.samplesheet)
        .splitCsv(header: true, sep: ',')

    // Check that there are only TWO groups
    samples_ch
        .map { it.group }
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

    // TODO: add m6anet support
    
    samples_split_ch = samples_ch.branch { row ->
        called: row.path_dorado
        uncalled: !row.path_dorado
    }

    called_ch = samples_split_ch.called
        .map { [it.name, it.group, file(it.path_dorado)] }

    uncalled_ch = DORADO_BASECALL_ALIGN(
        samples_split_ch.uncalled.map { [it.name, it.group, file(it.path_pod5)] },
        file(params.transcriptome)
    )

    basecalled_ch = called_ch.mix(uncalled_ch)

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

    aggregated_results = modkit_extract_ch
        .collectFile(keepHeader: true, skip: 1) {
            ["dorado_extracted_sites.csv","sample_name,group,file_path\n${it[0]},${it[1]},${it[2]}\n"]
        }
    
    reads_database_ch = PREP_FROM_DORADO(aggregated_results.map { ["dorado", it] })
        .first() // convert to value channel

    segments_ch = SITE_SELECTION(reads_database_ch)
        .flatMap { mod_caller, sites_db, reads_db, segments_file ->
            def seg = segments_file.splitCsv(header: true, sep: ',')
            seg.collect { row -> [mod_caller, sites_db, reads_db, row.start, row.end] }
        }

    // CALL_MODEL produces [A, B, C], groupTuple expects [[A, B], [C]] so we map and unmap accordingly
    diff_ch = CALL_MODEL(differential_models_ch.combine(segments_ch))
        .map { it -> [[it[0], it[1]], it[2]] }
        .groupTuple()
        .map { it -> [it[0][0], it[0][1], it[1]] }

    MERGE_TSVS(diff_ch)
}
