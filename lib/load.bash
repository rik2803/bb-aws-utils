[[ -z ${LIB_DIR} ]] && LIB_DIR="./bb-aws-utils/lib"

# shellcheck source=../../bb-aws-utils/lib/common.bash
[[ -z ${LIB_COMMON_LOADED} ]]    && source ${LIB_DIR:-lib}/common.bash    || true
# shellcheck source=../../bb-aws-utils/lib/aws.bash
[[ -z ${LIB_AWS_LOADED} ]]       && source ${LIB_DIR:-lib}/aws.bash       || true
# shellcheck source=../../bb-aws-utils/lib/dockerhub.bash
[[ -z ${LIB_DOCKERHUB_LOADED} ]] && source ${LIB_DIR:-lib}/dockerhub.bash || true
# shellcheck source=../../bb-aws-utils/lib/git.bash
[[ -z ${LIB_GIT_LOADED} ]]       && source ${LIB_DIR:-lib}/git.bash       || true
# shellcheck source=../../bb-aws-utils/lib/maven.bash
[[ -z ${LIB_MAVEN_LOADED} ]]     && source ${LIB_DIR:-lib}/maven.bash     || true
# shellcheck source=../../bb-aws-utils/lib/maven.bash
[[ -z ${LIB_GRADLE_LOADED} ]]    && source ${LIB_DIR:-lib}/gradle.bash    || true
# shellcheck source=../../bb-aws-utils/lib/install.bash
[[ -z ${LIB_INSTALL_LOADED} ]]   && source ${LIB_DIR:-lib}/install.bash   || true
