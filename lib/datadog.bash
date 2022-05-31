# shellcheck source=../../bb-aws-utils/lib/common.bash
[[ -z ${LIB_COMMON_LOADED} ]] && { source "${LIB_DIR:-lib}/common.bash"; }
export LIB_DATADOG_LOADED=1

datadog_deploy_monitors() {
  local docker_image="ixor/ansible-datadog-monitor:latest"

  # No deployment when all of these condition are met:
  #   DATADOG_MONITOR_AUTO_RUN not set or DATADOG_MONITOR_AUTO_RUN == 0
  #   DATADOG_MONITOR_ENVIRONMENT not set
  #   BITBUCKET_DEPLOYMENT_ENVIRONMENT not set
  if [[ -z "${DATADOG_MONITOR_AUTO_RUN}" || "${DATADOG_MONITOR_AUTO_RUN}" -eq 0 ]] && \
     [[ -z "${DATADOG_MONITOR_ENVIRONMENT}" ]] &&
     [[ -z "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}" ]]; then
     info "datadog monitors: Monitors will not be deployed because:"
     info "                  DATADOG_MONITOR_AUTO_RUN is not set or 0 AND"
     info "                  DATADOG_MONITOR_ENVIRONMENT is in the pipleine environment 0 AND"
     info "                  This pipeline is not a BB deployment"
     return 0
  fi

  info "datadog monitors: Check for ${BITBUCKET_CLONE_DIR}/dd_monitors.yml"

  if [[ ! -e "${BITBUCKET_CLONE_DIR}/dd_monitors.yml" ]]; then
    info "datadog monitors: ${BITBUCKET_CLONE_DIR}/dd_monitors.yml not found, will not create/update DD monitors"
    return 0
  fi

  info "datadog monitors: ${BITBUCKET_CLONE_DIR}/dd_monitors.yml found, will create/update DD monitors"

  if [[ -n "${DATADOG_MONITOR_ENVIRONMENT}" && -z "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}" ]]; then
    info "datadog monitors: Will only deploy datadog monitors for environment \"${DATADOG_MONITOR_ENVIRONMENT}\"."
  elif [[ -z "${DATADOG_MONITOR_ENVIRONMENT}" && -n "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}" ]]; then
    info "datadog monitors: Will only deploy datadog monitors for BB deployment \"${BITBUCKET_DEPLOYMENT_ENVIRONMENT}\"."
  elif [[ -n "${DATADOG_MONITOR_ENVIRONMENT}" && -n "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}" ]]; then
    info "datadog monitors: Will only deploy datadog monitors for BB deployment \"${BITBUCKET_DEPLOYMENT_ENVIRONMENT}\""
    info "                  and environment \"${DATADOG_MONITOR_ENVIRONMENT}\"."
  fi

  check_envvar DD_API_KEY R
  check_envvar DD_APP_KEY R

  docker pull -q "${docker_image}"
  docker run \
    -e DD_API_KEY="${DD_API_KEY}" \
    -e DD_APP_KEY="${DD_APP_KEY}" \
    -e DATADOG_MONITOR_ENVIRONMENT="${DATADOG_MONITOR_ENVIRONMENT:-all}" \
    -e BITBUCKET_DEPLOYMENT_ENVIRONMENT="${BITBUCKET_DEPLOYMENT_ENVIRONMENT:-all}" \
    -e BITBUCKET_REPO_SLUG="${BITBUCKET_REPO_SLUG:-NA}" \
    -e BITBUCKET_COMMIT="${BITBUCKET_COMMIT:-NA}" \
    -v ${BITBUCKET_CLONE_DIR}/dd_monitors.yml:/ansible/dd_monitors.yml \
    -v ${BITBUCKET_CLONE_DIR}/bb-aws-utils/ansible_datadog/playbook.yml:/ansible/playbook.yml \
    -v ${BITBUCKET_CLONE_DIR}/bb-aws-utils/ansible_datadog/datadog_monitors_template.j2:/ansible/datadog_monitors_template.j2 \
    "${docker_image}"
}
