[[ -z ${LIB_DIR} ]] && LIB_DIR="./bb-aws-utils/lib"

# shellcheck source=../../bb-aws-utils/lib/common.bash
[[ -z ${LIB_COMMON_LOADED} ]]    && source ${LIB_DIR:-lib}/common.bash      || true
# shellcheck source=../../bb-aws-utils/lib/install.bash
[[ -z ${LIB_INSTALL_LOADED} ]]   && source ${LIB_DIR:-lib}/install.bash     || true
# shellcheck source=../../bb-aws-utils/lib/install.bash
[[ -z ${LIB_BITBUCKET_LOADED} ]]   && source ${LIB_DIR:-lib}/bitbucket.bash || true
# shellcheck source=../../bb-aws-utils/lib/aws.bash
[[ -z ${LIB_AWS_LOADED} ]]       && source ${LIB_DIR:-lib}/aws.bash         || true
# shellcheck source=../../bb-aws-utils/lib/dockerhub.bash
[[ -z ${LIB_DOCKERHUB_LOADED} ]] && source ${LIB_DIR:-lib}/dockerhub.bash   || true
# shellcheck source=../../bb-aws-utils/lib/maven.bash
[[ -z ${LIB_DOCKER_LOADED} ]]    && source ${LIB_DIR:-lib}/docker.bash      || true
# shellcheck source=../../bb-aws-utils/lib/git.bash
[[ -z ${LIB_GIT_LOADED} ]]       && source ${LIB_DIR:-lib}/git.bash         || true
# shellcheck source=../../bb-aws-utils/lib/maven.bash
[[ -z ${LIB_MAVEN_LOADED} ]]     && source ${LIB_DIR:-lib}/maven.bash       || true
# shellcheck source=../../bb-aws-utils/lib/maven.bash
[[ -z ${LIB_GRADLE_LOADED} ]]    && source ${LIB_DIR:-lib}/gradle.bash      || true

export AWS_PAGER=""
[[ -e /tmp ]] || mkdir -p /tmp

install_set_linux_distribution_type
aws_set_service_account_config
aws_set_codeartifact_token
maven_create_settings_xml
gradle_create_gradle_properties