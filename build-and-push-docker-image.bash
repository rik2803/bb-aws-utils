#! /bin/bash

unset LIB_COMMON_LOADED LIB_AWS_LOADED LIB_DOCKERHUB_LOADED LIB_GIT_LOADED LIB_MAVEN_LOADED LIB_GRADLE_LOADED LIB_INSTALL_LOADED

scriptdir=$(dirname "${0}")
export LIB_DIR="${scriptdir}/lib"
source ${scriptdir}/lib.bash

install_awscli
set_source_ecr_credentials
docker_build_deploy_image
set_dest_ecr_credentials
docker_tag_and_push_deploy_image
