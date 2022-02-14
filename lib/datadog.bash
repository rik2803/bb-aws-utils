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

  install_ansible
  cp "${BITBUCKET_CLONE_DIR}/dd_monitors.yml" "${BITBUCKET_CLONE_DIR}/bb-aws-utils/ansible_datadog/dd_monitors.yml"
  cd "${BITBUCKET_CLONE_DIR}/bb-aws-utils/ansible_datadog"
  info "Start creating the playbook from the template and the config"
  ansible-playbook playbook.yml
  if is_debug_enabled; then
    info "Display created Ansible playbook."
    cat playbook_dd_monitors.yml
  fi
  info "Deploying the DD monitors."
  ansible-playbook playbook_dd_monitors.yml

  cd -
}
