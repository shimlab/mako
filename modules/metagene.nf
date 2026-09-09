process CREATE_METAGENE {
    label 'single_cpu'
    publishDir "${params.outdir}/metagene", mode: params.publish_dir_mode

    input:
    path(sites_db)
    path(gtf_db)

    output:
    path("metagene.html"), emit: html
    path("metagene.pdf"), emit: pdf

    script:
    """
    # Quarto writes to the user cache/data dirs, which may not exist (or be
    # writable) in the container -- keep everything inside the task work dir.
    export HOME="\$PWD"
    export XDG_CACHE_HOME="\$PWD/.cache"
    export XDG_DATA_HOME="\$PWD/.local/share"

    # Quarto runs with the working directory set to the .qmd's own folder, so render a
    # copy inside the task work dir -- otherwise it cannot see the databases and would
    # write its output into the repo.
    cp ${projectDir}/bin/create_metagene.qmd .

    quarto render create_metagene.qmd \\
        --to html \\
        --output metagene.html \\
        -P sites_db:${sites_db} \\
        -P gtf_db:${gtf_db} \\
        -P mod_threshold:${params.mod_threshold} \\
        -P min_reads:${params.min_reads_per_sample}

    # quarto render create_metagene.qmd \\
    #     --to typst \\
    #     --output metagene.pdf \\
    #     -P sites_db:${sites_db} \\
    #     -P gtf_db:${gtf_db} \\
    #     -P mod_threshold:${params.mod_threshold} \\
    #     -P min_reads:${params.min_reads_per_sample}
    """

    stub:
    """
    touch metagene.html metagene.pdf
    """
}
