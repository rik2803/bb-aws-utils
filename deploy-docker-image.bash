#! /bin/bash

unset LIB_COMMON_LOADED LIB_AWS_LOADED LIB_DOCKERHUB_LOADED LIB_GIT_LOADED LIB_MAVEN_LOADED LIB_GRADLE_LOADED LIB_INSTALL_LOADED LIB_NPM_LOADED

scriptdir=$(dirname "${0}")
export LIB_DIR="${scriptdir}/lib"
source ${scriptdir}/lib.bash

install_awscli
set_dest_ecr_credentials
docker_deploy_image
