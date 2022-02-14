# shellcheck source=../../bb-aws-utils/lib/common.bash
[[ -z ${LIB_COMMON_LOADED} ]] && { source "${LIB_DIR:-lib}/common.bash"; }
export LIB_DATADOG_LOADED=1

datadog_deploy_monitors() {
  info "datadog: Check for ${BITBUCKET_CLONE_DIR}/dd_monitors.yml"
  if [[ ! -e "${BITBUCKET_CLONE_DIR}/dd_monitors.yml" ]]; then
    info "datadog: ${BITBUCKET_CLONE_DIR}/dd_monitors.yml not found, will not create/update DD monitors"
    return 0
  fi

  info "datadog: ${BITBUCKET_CLONE_DIR}/dd_monitors.yml found, will create/update DD monitors"
  check_envvar DD_API_KEY R
  check_envvar DD_APP_KEY R

  docker run \
    -e DD_API_KEY="${DD_API_KEY}" \
    -e DD_APP_KEY="${DD_APP_KEY}" \
    -v ${BITBUCKET_CLONE_DIR}/dd_monitors.yml:/ansible/dd_monitors.yml \
    -v ${BITBUCKET_CLONE_DIR}/bb-aws-utils/ansible_datadog/playbook.yml:/ansible/playbook.yml \
    -v ${BITBUCKET_CLONE_DIR}/bb-aws-utils/ansible_datadog/datadog_monitors_template.j2:/ansible/datadog_monitors_template.j2 \
    ixor/ansible-datadog-monitor:latest

}
