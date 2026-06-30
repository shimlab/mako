process MAKOVIEW_INIT {
    publishDir "${params.outdir}/makoview", mode: 'copy'
    label 'single_cpu'
    cache 'lenient'
    
    container ''

    input:
    path gtf
    path genome

    output:
    val relative_gtf_file, emit: gtf_file
    val relative_genome_file, emit: genome_file
    // emitting paths here so they are published
    path "makoview_venv"
    
    script:
    relative_gtf_file = "ref/${gtf.name}"
    relative_genome_file = "ref/${genome.name}"

    """
    set -euxo pipefail

    python -m venv makoview_venv
    
    source makoview_venv/bin/activate
    pip install makoview==0.2.0

    # create symlinks to gtf and genome files
    GTF_PATH=\$(realpath "${gtf}")
    GENOME_PATH=\$(realpath "${genome}")

    cd ${launchDir}
    mkdir -p "${params.outdir}/makoview/ref"
    cd "${params.outdir}/makoview"

    ln -s \$GTF_PATH $relative_gtf_file
    ln -s \$GENOME_PATH $relative_genome_file

    makoview init \
        --gtf ${relative_gtf_file} \
        --genome ${relative_genome_file}
    """

    stub:
    """
    """
}

process MAKOVIEW_CREATE_LAUNCH_SCRIPT {
    publishDir "${params.outdir}/makoview", mode: 'copy'
    label 'local'
    
    container ''

    input:
    val gtf_file
    val genome_file
    val _ready

    output:
    path "launch_makoview.sh"

    // TODO: change paths to reflect new directory structure
    script:
    """
    SCRIPT_CONTENTS=\$(cat << 'EOF'
    #!/bin/bash

    # Change to the directory of this script
    cd "\$(dirname "\${BASH_SOURCE[0]}")" || exit 1

    source makoview_venv/bin/activate

    # select the correct fits TSV file
    files=(../differential/dorado/*.tsv)
    
    if [ \${#files[@]} -eq 1 ]; then
        FITS_TSV="\${files[0]}"
    else
        PS3="Select a result: "
        select FITS_TSV in "\${files[@]}"; do
            if [ -n "\${FITS_TSV:-}" ]; then
                break
            else
                echo "Invalid selection, try again." >&2
            fi
        done
    fi

    makoview serve \\
        --genome ${genome_file} \\
        --gtf ${gtf_file} \\
        --sites ../differential/dorado/sites.duckdb \\
        --coverage ../db/coverage.dorado.duckdb \\
        --reads ../modcall/dorado/all_sites.duckdb \\
        --fits \$FITS_TSV \\
        --port 52348
    EOF
    )

    echo "\$SCRIPT_CONTENTS" > launch_makoview.sh
    chmod +x launch_makoview.sh
    """

    stub:
    """
    echo "test" > launch_makoview.sh
    """
}