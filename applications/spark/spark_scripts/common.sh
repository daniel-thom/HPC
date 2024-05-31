function error()
{
    echo "Error: ${@}"
    exit 1
}

function get_config_variable()
{
    name=$1
    if [ -z $name ]; then
        echo "Error: name must be provided"
        exit 1
    fi
    if [ -z ${CONFIG_DIR} ]; then
        echo "Error: CONFIG_DIR is not set"
        exit 1
    fi
    var=$(grep "^${name}\s*=" ${CONFIG_DIR}/config | awk -F "=" '{ print $2}' | tr -d " ")
    if [ -z ${var} ]; then
        echo "Error: Failed to parse config variable ${name}"
        exit 1
    fi
    echo "${var}"
}

export CONTAINER_PATH=$(get_config_variable "container")
export CONTAINER_NAME=$(get_config_variable "container_instance_name")
export NODE_MEMORY_OVERHEAD_GB=$(get_config_variable "node_memory_overhead_gb")

# Note: NREL_CLUSTER is always set on Kestrel nodes.
# It is not set on Eagle if you ssh into one of your allocated nodes, which is what these
# scripts do.
if [ ! -z ${NREL_CLUSTER} ] && [ ${NREL_CLUSTER} == "kestrel" ]; then
    module load apptainer
    export CONTAINER_MODULE=apptainer
    export CONTAINER_EXEC=apptainer
    export LUSTRE_BIND_MOUNTS=" -B /nopt:/nopt \
        -B /projects:/projects \
        -B /scratch:/scratch \
        -B /datasets:/datasets \
        -B /kfs2:/kfs2 \
        -B /kfs3:/kfs3"
else
    export CONTAINER_MODULE=singularity-container
    export CONTAINER_EXEC=singularity
    export LUSTRE_BIND_MOUNTS=" -B /nopt:/nopt \
        -B /datasets:/datasets \
        -B /lustre:/lustre \
        -B /projects:/projects \
        -B /scratch:/scratch"
fi

function get_memory_gb()
{
    memory_kb=$(grep "MemTotal.*kB" /proc/meminfo | awk '{print $2}')
    memory_gb=$(( ${memory_kb} / (1024 * 1024) ))
    echo "${memory_gb}"
}

function get_num_cpus()
{
    echo "$(grep -c processor /proc/cpuinfo)"
}

function get_spark_bind_mounts()
{
    echo "-B ${CONFIG_DIR}/conf/:/opt/spark/conf"
}

function get_spark_driver_memory_gb()
{
    cfile=${CONFIG_DIR}/conf/spark-defaults.conf
    mem=$(grep ^spark.driver.memory ${cfile} \
        | sed -E "s/spark.driver.memory\s*=*\s*([[:digit:]]+)g/\1/")
    echo "${mem}" | grep spark
    if [ $? -eq 0 ]; then
        echo "Did not find spark.driver.memory in ${cfile}"
        exit 1
    fi
    echo "${mem}"
}

function get_node_memory_overhead_gb()
{
    if is_heterogeneous_slurm_job; then
        echo "${NODE_MEMORY_OVERHEAD_GB}"
    else
        driver_mem=$(get_spark_driver_memory_gb)
        node_memory_overhead_gb=$(( ${driver_mem} + ${NODE_MEMORY_OVERHEAD_GB} ))
        echo "${node_memory_overhead_gb}"
    fi
}

function is_heterogeneous_slurm_job()
{
    if [ -z ${SLURM_HET_SIZE} ]; then
        return 1
    fi
    return 0
}

function is_worker_node()
{
    if [ -z $1 ]; then
        echo "A node name must be passed to is_worker_node()"
        exit 1
    fi
    if [ -z ${SLURM_NODELIST_HET_GROUP_0} ]; then
        return 0
    fi
    node=$1
    if [ ${node} == ${SLURM_NODELIST_HET_GROUP_0} ]; then
        return 1
    fi
    return 0
}

function exec_spark_process()
{
    if [ -z ${1} ]; then
        echo "Error: A command must be passed to exec_spark_process"
        exit 1
    fi
    cmd=$@
    ${CONTAINER_EXEC} exec \
        ${LUSTRE_BIND_MOUNTS} \
        $(get_spark_bind_mounts ${CONFIG_DIR}) \
        instance://${CONTAINER_NAME} \
        ${cmd}
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "Failed to exec Spark command=[${cmd}]: ${ret}"
        exit $ret
    fi
}

function check_history_server_enabled()
{
    # $? will be 0 if the history server is enabled
    grep "^\s*spark\.eventLog\.enabled\s*=*\s*true" ${CONFIG_DIR}/conf/spark-defaults.conf
}
