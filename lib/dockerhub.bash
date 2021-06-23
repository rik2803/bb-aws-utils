# shellcheck source=../../bb-aws-utils/lib/common.bash
[[ -z ${LIB_COMMON_LOADED} ]] && { source "${LIB_DIR:-lib}/common.bash"; }
export LIB_DOCKERHUB_LOADED=1

dockerhub_login() {
  check_envvar DOCKERHUB_USERNAME R
  check_envvar DOCKERHUB_PASSWORD R

  run_cmd docker login --username="${DOCKERHUB_USERNAME}" --password="${DOCKERHUB_PASSWORD}"
}
