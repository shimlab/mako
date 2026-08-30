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
    
    script:
    relative_gtf_file = "ref/${gtf.name}"
    relative_genome_file = "ref/${genome.name}"

    """
    set -euxo pipefail

    cd ${launchDir}
    mkdir -p "${params.outdir}/makoview/ref"
    cd "${params.outdir}/makoview"

    python -m venv makoview_venv
    
    source makoview_venv/bin/activate
    pip install makoview==0.2.3

    # create symlinks to gtf and genome files
    GTF_PATH=\$(realpath "${gtf}")
    GENOME_PATH=\$(realpath "${genome}")

    # if the symlinks already exist, don't fail - just continue silently
    # chances are, these were created by a previous invocation of this process
    ln -s \$GTF_PATH $relative_gtf_file || true
    ln -s \$GENOME_PATH $relative_genome_file || true

    makoview init \
        --gtf ${relative_gtf_file} \
        --genome ${relative_genome_file}
    """

    stub:
    relative_gtf_file = "ref/${gtf.name}"
    relative_genome_file = "ref/${genome.name}"

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

    script:
    """
    SCRIPT_CONTENTS=\$(cat << 'EOF'
    #!/bin/bash

    # Change to the directory of this script
    cd "\$(dirname "\${BASH_SOURCE[0]}")" || exit 1

    source makoview_venv/bin/activate

    makoview serve \\
        --genome   ${genome_file} \\
        --gtf      ${gtf_file} \\
        --sites    ../differential/sites.duckdb \\
        --coverage ../db/coverage.duckdb \\
        --reads    ../db/reads.duckdb \\
        --fits     ../differential/model_calls.tsv \\
        --port     52348 \\
        --modified_prob_threshold ${params.mod_threshold}
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