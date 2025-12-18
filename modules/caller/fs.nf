// this module contains filesystem management functionality which allows for the retrieval and automatic removal of large files

process RETRIEVE_FILE {
    label "local"
    maxForks 1

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/awscli:2.32.19--e808772ebfc5a38c' :
        'community.wave.seqera.io/library/awscli:2.32.19--d072bf435ab38686' }"

    input:
    tuple val(sample_name), val(group), val(s3_url)
    val temp_dir

    output:
    tuple val(sample_name), val(group), val(out_file)

    script:
    out_file = temp_dir + "/" + sample_name + "_" + group + ".out"
    temp_lock = temp_dir + "lockfile"
    """
    mkdir -p ${temp_dir}

    # wait for lock to lift
    [[ -f lockfile ]] && while [[ \$(cat ${temp_lock}) != "0" ]]; do sleep 2; done
    
    # create lock
    echo 1 > ${temp_lock}
    aws s3 sync "${s3_url}" ${out_file} --no-sign-request
    """

    stub:
    out_file = temp_dir + "/" + sample_name + "_" + group + ".out"
    temp_lock = temp_dir + "lockfile"
    """
    mkdir -p ${temp_dir}

    # wait for lock to lift
    [[ -f lockfile ]] && while [[ \$(cat ${temp_lock}) != "0" ]]; do sleep 2; done
    
    # create lock
    echo 1 > ${temp_lock}

    touch ${out_file}
    """
}

process REMOVE_FILE {
    label "local"

    input:
    tuple val(sample_name), val(group)
    val temp_dir

    script:
    out_file = temp_dir + "/" + sample_name + "_" + group + ".out"
    temp_lock = temp_dir + "lockfile"
    """
    rm -f ${out_file}
    echo 0 > ${temp_lock}
    """

    stub:
    temp_lock = temp_dir + "lockfile"
    """
    echo "removing file"
    echo 0 > ${temp_lock}
    """
}