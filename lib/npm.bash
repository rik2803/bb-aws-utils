# shellcheck source=../../bb-aws-utils/lib/common.bash
[[ -z ${LIB_COMMON_LOADED} ]]  && { source "${LIB_DIR:-lib}/common.bash"; }
# shellcheck source=../../bb-aws-utils/lib/git.bash
[[ -z ${LIB_GIT_LOADED} ]]     && { source "${LIB_DIR:-lib}/git.bash"; }
# shellcheck source=../../bb-aws-utils/lib/install.bash
[[ -z ${LIB_INSTALL_LOADED} ]] && { source "${LIB_DIR:-lib}/install.bash"; }

export LIB_NPM_LOADED=1

npm_create_npmrc() {
  if [[ -n ${NPM_TOKEN} ]]; then
    info "${FUNCNAME[0]} - Create ~/.npmrc file for NPMJS authentication."
    echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > ~/.npmrc
  fi

  return 0
}
