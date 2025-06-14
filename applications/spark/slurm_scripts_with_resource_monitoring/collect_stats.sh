#!/bin/bash

# Note: You many need to activate a Python environment here.
# module load python
# source ~/python-envs/<my-end>/bin/activate

if [ -z $1 ]; then
    echo "Error: CONFIG_DIR must be passed to collect-stats.sh"
    exit 1
fi
config_dir=$(realpath ${1})
out_dir=${config_dir}/stats-$(hostname)
# Start collecting stats as a background operation.
rmon collect \
    --name=$(hostname) \
    --output=${out_dir} \
    --interval=3 \
    --cpu \
    --disk \
    --memory \
    --network \
    --plots \
    --overwrite &

# Wait until the parent process creates the file shutdown.
while ! [ -f shutdown ];
do
    sleep 5
done

# This will inform rmon to stop collection, make plots, and shut down.
for pid in $(pgrep -f "rmon collect");
do
    kill -TERM ${pid}
done

while [ $(pgrep -f "rmon collect") ];
do
    sleep 1
done
