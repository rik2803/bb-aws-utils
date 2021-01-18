#! /bin/bash

scriptdir=$(dirname "${0}")
export LIB_DIR="${scriptdir}/lib"
source ${scriptdir}/lib.bash

install_awscli
docker_build_application_image
set_dest_ecr_credentials
docker_tag_and_push_application_image
