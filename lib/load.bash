[[ -z ${LIB_DIR} ]] && LIB_DIR="./bb-aws-utils/lib"

# shellcheck source=../../bb-aws-utils/lib/common.bash
[[ -z ${LIB_COMMON_LOADED} ]]    && source ${LIB_DIR:-lib}/common.bash      || true
# shellcheck source=../../bb-aws-utils/lib/install.bash
[[ -z ${LIB_INSTALL_LOADED} ]]   && source ${LIB_DIR:-lib}/install.bash     || true
# shellcheck source=../../bb-aws-utils/lib/install.bash
[[ -z ${LIB_BITBUCKET_LOADED} ]]   && source ${LIB_DIR:-lib}/bitbucket.bash || true
# shellcheck source=../../bb-aws-utils/lib/aws.bash
[[ -z ${LIB_AWS_LOADED} ]]       && source ${LIB_DIR:-lib}/aws.bash         || true
# shellcheck source=../../bb-aws-utils/lib/aws-s3-artifact.bash
[[ -z ${LIB_AWS_S#_ARTIFACT_LOADED} ]] && source ${LIB_DIR:-lib}/aws-s3-artifact.bash || true
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

### Keep this at the end
# CONFIG_ENV:
#   * The environment (tst, stg, acc, prd, ...) the config repo is used for.
#   * Derived from BITBUCKET_REPO_SLUG (i.e. myproject.config.tst)
#   * Used for naming artifacts (Docker images, ZIP artifacts)

PARENT_SLUG="${PARENT_SLUG:-$(get_parent_slug_from_repo_slug)}"
CONFIG_ENV="${CONFIG_ENV:-$(get_config_env_from_repo_slug)}"