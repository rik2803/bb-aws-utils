#! /bin/bash

scriptdir=$(dirname "${0}")

source ${scriptdir}/lib.bash

install_awscli
docker_deploy_image
