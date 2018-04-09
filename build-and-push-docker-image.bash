#! /bin/bash

scriptdir=$(dirname "${0}")

source ${scriptdir}/lib.bash

install_awscli
set_source_ecr_credentials
docker_build_deploy_image
set_dest_ecr_credentials
docker_tag_and_push_deploy_image
