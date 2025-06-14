#!/bin/bash
CONFIG_DIR=$1
if [ -z ${CONFIG_DIR} ]; then
	echo "CONFIG_DIR was not passed to make_dropbear.sh"
	exit 1
fi
mkdir ${CONFIG_DIR}/dropbear
cd ${CONFIG_DIR}/dropbear
dropbearkey -t rsa -s 4096 -f dropbear_rsa_host_key
dropbearkey -t dss -s 1024 -f dropbear_dss_host_key
dropbearkey -t ecdsa -s 521 -f dropbear_ecdsa_host_key
cd -
