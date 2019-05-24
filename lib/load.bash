[[ -z ${LIB_COMMON_LOADED} ]]    && { source ${LIB_DIR:-lib}/common.bash; }
[[ -z ${LIB_AWS_LOADED} ]]       && { source ${LIB_DIR:-lib}/aws.bash; }
[[ -z ${LIB_DOCKERHIB_LOADED} ]] && { source ${LIB_DIR:-lib}/dockerhub.bash; }
[[ -z ${LIB_GIT_LOADED} ]]       && { source ${LIB_DIR:-lib}/git.bash; }
[[ -z ${LIB_MAVEN_LOADED} ]]     && { source ${LIB_DIR:-lib}/maven.bash; }
[[ -z ${LIB_INSTALL_LOADED} ]]   && { source ${LIB_DIR:-lib}/install.bash; }
