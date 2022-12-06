# shellcheck source=../../bb-aws-utils/lib/common.bash
[[ -z ${LIB_COMMON_LOADED} ]] && { source "${LIB_DIR:-lib}/common.bash"; }
export LIB_SNYK_LOADED=1

_snyk_prerun_checks() {
  [[ -z "${SNYK_TOKEN}" ]] && { info "SNYK_TOKEN not set."; return 1; }
  [[ -n "${SNYK_SKIP_TEST}" && ${SNYK_SKIP_TEST} -eq 1  ]] && { warning "SNYK_SKIP_TEST is set and 1, skipping sny test (NOT GOOD!!)."; return 1; }
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
  _snyk_prerun_checks || return
  info "snyk: SNYK_TOKEN is set, starting Snyk analysis."
  _snyk_install_snyk
  /snyk test --severity-threshold="${SNYK_SEVERITY_THRESHOLD:-high}" --all-projects
}

snyk_run_docker_test() {
  # This requires that the image be already available
  _snyk_prerun_checks || return

  check_envvar DOCKERFILE R

  DOCKER_IMAGE="$(maven_get_property_from_pom docker.image.registry)/$(maven_get_property_from_pom docker-image-registry.group)/$(maven_get_property_from_pom project.name):latest"

  info "snyk: SNYK_TOKEN is set, starting Snyk container analysis."
  _snyk_install_snyk
  /snyk container test "${DOCKER_IMAGE}" \
    --file="${DOCKERFILE}" \
    --severity-threshold="${SNYK_SEVERITY_THRESHOLD:-high}"
}
