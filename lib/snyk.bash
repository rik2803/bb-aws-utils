# shellcheck source=../../bb-aws-utils/lib/common.bash
[[ -z ${LIB_COMMON_LOADED} ]] && { source "${LIB_DIR:-lib}/common.bash"; }
export LIB_SNYK_LOADED=1
export LIB_SNYK_TEST_ALREADY_PERFORMED=0

_snyk_prerun_checks() {
  [[ -z "${SNYK_TOKEN}" ]] && { info "SNYK_TOKEN not set."; return 1; }
  [[ -n "${SNYK_SKIP_TEST}" && ${SNYK_SKIP_TEST} -eq 1  ]] && { warning "SNYK_SKIP_TEST is set and 1, skipping snyk test (NOT GOOD!!)."; return 1; }
  return 0
}

_snyk_install_snyk() {
  local snyk_cli_url="https://static.snyk.io/cli/latest/snyk-linux"

  if [[ -x /snyk ]]; then
    info "Snyk CLI already installed."
  else
    check_command curl || install_sw curl
    info "snyk: Download Snyk CLI ..."
    run_cmd curl -s "${snyk_cli_url}" -o /snyk
    run_cmd chmod 0755 /snyk
  fi
}

snyk_run_test() {
  local snyk_target_reference

  _snyk_prerun_checks || return
  info "snyk: SNYK_TOKEN is set, starting Snyk analysis."
  if [[ ${LIB_SNYK_TEST_ALREADY_PERFORMED} -ne 0 ]]; then
    info "snyk: snyk test was already run in this pipeline, skipping this run."
  fi

  snyk_target_reference=$(git_get_current_branch)
  if [[ "${snyk_target_reference}" == "main" || "${snyk_target_reference}" == "master" ]]; then
    snyk_target_reference="rc"
  fi

   _snyk_install_snyk

  info "snyk: Run snyk monitor with target-reference \"${snyk_target_reference}\" to register project with Snyk back-end"
  /snyk monitor --target-reference="${snyk_target_reference}"  --all-projects

  info "snyk: Run /snyk test --severity-threshold=\"${SNYK_SEVERITY_THRESHOLD:-high}\" --all-projects to check dependencies"
  if /snyk test --severity-threshold="${SNYK_SEVERITY_THRESHOLD:-high}" --all-projects; then
    info "Snyk test passed, continuing pipeline ..."
  else
    fail "Snyk test failed, aborting pipeline."
  fi

  LIB_SNYK_TEST_ALREADY_PERFORMED=1
}

snyk_run_docker_test() {
  # This requires that the image be already available
  _snyk_prerun_checks || return
  info "snyk: SNYK_TOKEN is set, starting Snyk container analysis."
  _snyk_install_snyk

  check_envvar DOCKERFILE O ./src/main/docker/Dockerfile
  check_envvar DOCKER_IMAGE O "$(maven_get_property_from_pom docker.image.registry)/$(maven_get_property_from_pom docker-image-registry.group)/$(maven_get_property_from_pom project.name):latest)"

  info "snyk: Run snyk container monitor to register project with Snyk back-end"
  /snyk container monitor --file="${DOCKERFILE}" \
                          --severity-threshold="${SNYK_SEVERITY_THRESHOLD:-high}" \
                          "${DOCKER_IMAGE}"

  info "snyk: Run /snyk container test --file=\"${DOCKERFILE}\" --severity-threshold=\"${SNYK_SEVERITY_THRESHOLD:-high}\" \"${DOCKER_IMAGE}\" to check dependencies"
  if /snyk container test \
    --file="${DOCKERFILE}" \
    --severity-threshold="${SNYK_SEVERITY_THRESHOLD:-high}" \
    "${DOCKER_IMAGE}"; then
    info "Snyk container test passed, continuing pipeline ..."
  else
    fail "Snyk container test failed, aborting pipeline."
  fi
}
