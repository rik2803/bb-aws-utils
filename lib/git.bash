# shellcheck source=../../bb-aws-utils/lib/common.bash
[[ -z ${LIB_COMMON_LOADED} ]] && { source "${LIB_DIR:-lib}/common.bash"; }
# shellcheck source=../../bb-aws-utils/lib/install.bash
[[ -z ${LIB_INSTALL_LOADED} ]] && { source "${LIB_DIR:-lib}/install.bash"; }
LIB_GIT_LOADED=1

git_current_commit_message() {
  check_command git || install_sw git

  run_cmd git log --format=%B -n 1
}

git_set_user_config() {
  git config --global user.email "${GIT_EMAIL:-cicd@domain.com}"
  git config --global user.name "${GIT_USERNAME:-cicd}"
}

git_clone_repo() {
  info "${FUNCNAME[0]} - Trying to clone ${1} into ${2:-remote_repo}"
  git clone "${1}" "${2:-remote_repo}" || fail "${FUNCNAME[0]} - Error cloning ${1}"
}

git_rm_tag() {
  if git tag | grep -q "${1:-999.999}"
  then
    info "${FUNCNAME[0]} - Tag ${1:-999.999} already exists, removing it locally and remotely."
    git tag -d "${1:-999.999}"
    git push --delete origin "${1:-999.999}"
  fi
}

git_set_tag() {
  info "${FUNCNAME[0]} - Setting tag ${1} on HEAD and pushing to origin."
  git tag "${1}"
  git push --tags
}

git_branch_exists() {
  local repo_url="${1}"
  local branch="${2:-master}"

  if git ls-remote --heads "${repo_url}" 2>/dev/null | grep -q "refs/heads/${branch}$"; then
    return 0
  else
    return 1
  fi
}
