[[ -z ${LIB_COMMON_LOADED} ]]    && source ${LIB_DIR:-lib}/common.bash    || true
[[ -z ${LIB_AWS_LOADED} ]]       && source ${LIB_DIR:-lib}/aws.bash       || true
[[ -z ${LIB_DOCKERHIB_LOADED} ]] && source ${LIB_DIR:-lib}/dockerhub.bash || true
[[ -z ${LIB_GIT_LOADED} ]]       && source ${LIB_DIR:-lib}/git.bash       || true
[[ -z ${LIB_MAVEN_LOADED} ]]     && source ${LIB_DIR:-lib}/maven.bash     || true
[[ -z ${LIB_INSTALL_LOADED} ]]   && source ${LIB_DIR:-lib}/install.bash   || true
