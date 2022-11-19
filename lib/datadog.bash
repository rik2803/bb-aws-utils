# shellcheck source=../../bb-aws-utils/lib/common.bash
[[ -z ${LIB_COMMON_LOADED} ]] && { source "${LIB_DIR:-lib}/common.bash"; }
export LIB_DATADOG_LOADED=1

datadog_deploy_monitors() {
  local docker_image="ixor/ansible-datadog-monitor:latest"

  # No deployment when all of these condition are met:
  #   DATADOG_MONITOR_AUTO_RUN not set or DATADOG_MONITOR_AUTO_RUN == 0
  #   DATADOG_MONITOR_ENVIRONMENT not set
  #   BITBUCKET_DEPLOYMENT_ENVIRONMENT not set
  if [[ -z "${DATADOG_MONITOR_AUTO_RUN}" || "${DATADOG_MONITOR_AUTO_RUN}" -eq 0 ]] &&
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

  # When bb-aws-utils is cloned outside BITBUCKET_CLONE_DIR, the files ${LIB_DIR}/ansible_datadog/playbook.yml and
  # ${LIB_DIR}/ansible_datadog/datadog_monitors_template.j2 should be copied somewhere under BITBUCKET_CLONE_DIR because
  # BB pipelines only accepts files under BITBUCKET_CLONE_DIR to be passed in the docker volume mount arguments. The
  # error produced otherwise by the pipeline is:
  #
  # docker: Error response from daemon: authorization denied by plugin pipelines: -v only supports $BITBUCKET_CLONE_DIR and its subdirectories.
  #    See 'docker run --help'.

  ANSIBLE_PLAYBOOK_SOURCE_DIR="${BITBUCKET_CLONE_DIR}/bb-aws-utils-datadog-tmp"
  mkdir -p "${ANSIBLE_PLAYBOOK_SOURCE_DIR}"
  cp ${LIB_DIR}/../ansible_datadog/* "${ANSIBLE_PLAYBOOK_SOURCE_DIR}"

  info "Content of ${ANSIBLE_PLAYBOOK_SOURCE_DIR}:"
  ls -l "${ANSIBLE_PLAYBOOK_SOURCE_DIR}"

  docker pull -q "${docker_image}"
  docker run \
    -e DD_API_KEY="${DD_API_KEY}" \
    -e DD_APP_KEY="${DD_APP_KEY}" \
    -e DD_API_HOST="${DD_API_HOST:-https://api.datadoghq.com}" \
    -e DATADOG_MONITOR_ENVIRONMENT="${DATADOG_MONITOR_ENVIRONMENT:-all}" \
    -e BITBUCKET_DEPLOYMENT_ENVIRONMENT="${BITBUCKET_DEPLOYMENT_ENVIRONMENT:-all}" \
    -e BITBUCKET_REPO_SLUG="${BITBUCKET_REPO_SLUG:-NA}" \
    -e BITBUCKET_COMMIT="${BITBUCKET_COMMIT:-NA}" \
    -v ${BITBUCKET_CLONE_DIR}/dd_monitors.yml:/ansible/dd_monitors.yml \
    -v ${ANSIBLE_PLAYBOOK_SOURCE_DIR}/playbook.yml:/ansible/playbook.yml \
    -v ${ANSIBLE_PLAYBOOK_SOURCE_DIR}/datadog_monitors_template.j2:/ansible/datadog_monitors_template.j2 \
    "${docker_image}"
}
