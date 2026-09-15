process MAKOVIEW_INIT {
    publishDir "${params.outdir}/makoview", mode: 'copy'
    label 'single_cpu'
    cache 'lenient'
    
    container ''

    input:
    path genome

    output:
    val relative_genome_file, emit: genome_file
    
    script:
    relative_genome_file = "ref/${genome.name}"

    """
    set -euxo pipefail

    # get real path of the genome file, as it is a symlink
    GENOME_PATH=\$(realpath "${genome}")

    cd ${launchDir}
    mkdir -p "${params.outdir}/makoview/ref"
    cd "${params.outdir}/makoview"

    python -m venv makoview_venv
    
    source makoview_venv/bin/activate
    
    pip install makoview==0.2.4.1

    # if the symlink already exists, don't fail - just continue silently
    # chances are, it was created by a previous invocation of this process
    ln -s \$GENOME_PATH $relative_genome_file || true

    makoview init \
        --genome "${relative_genome_file}"
    """

    stub:
    relative_genome_file = "ref/${genome.name}"

    """
    """
}

process MAKOVIEW_CREATE_LAUNCH_SCRIPT {
    publishDir "${params.outdir}/makoview", mode: 'copy'
    label 'local'
    
    container ''

    input:
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
        --gtf_db   ../db/gtf_features.duckdb \\
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
