#! /bin/bash

scriptdir=$(dirname "${0}")
export LIB_DIR="${scriptdir}/lib"
source ${scriptdir}/lib.bash

install_awscli
set_dest_ecr_credentials
docker_deploy_image
