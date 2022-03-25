# shellcheck source=../../bb-aws-utils/lib/common.bash
[[ -z ${LIB_COMMON_LOADED} ]] && { source "${LIB_DIR:-lib}/common.bash"; }
export LIB_SNYK_LOADED=1

snyk_run_test() {
  local snyk_cli_url="https://static.snyk.io/cli/latest/snyk-linux"

  if [[ -n "${SNYK_TOKEN}" ]]; then
    info "snyk: SNYK_TOKEN is set, starting Snyk analysis."
    info "snyk: Download Snyk CLI ..."
    curl -s "${snyk_cli_url}" /snyk && chmod 0755 /snyk
    info "snyk: Run snyk test"
    [[ -e "${BITBUCKET_CLONE_DIR}/pom.xml" ]] && /snyk test -- "-s /settings.xml"
  else
    info "SNYK_TOKEN envvar not set, skip Snyk analysis."
  fi
}
