# shellcheck source=../../bb-aws-utils/lib/common.bash
[[ -z ${LIB_COMMON_LOADED} ]] && { source "${LIB_DIR:-lib}/common.bash"; }
export LIB_SNYK_LOADED=1

snyk_run_test() {
  local snyk_cli_url="https://static.snyk.io/cli/latest/snyk-linux"

  [[ -z "${SNYK_TOKEN}" ]] && { info "SNYK_TOKEN not set."; return; }
  [[ -n "${SNYK_SKIP_TEST}" && ${SNYK_SKIP_TEST} -eq 1  ]] && { warning "SNYK_SKIP_TEST is set and 1, skipping sny test (NOT GOOD!!)."; return; }

  check_command curl || install_sw curl
  info "snyk: SNYK_TOKEN is set, starting Snyk analysis."
  info "snyk: Download Snyk CLI ..."
  run_cmd curl -s "${snyk_cli_url}" -o /snyk
  run_cmd chmod 0755 /snyk
  info "snyk: Run snyk test"
  /snyk test --severity-threshold="${SNYK_SEVERITY_THRESHOLD:-high}" --all-projects
}
