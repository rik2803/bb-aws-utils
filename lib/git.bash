[[ -z ${LIB_COMMON_LOADED} ]] && { source ${LIB_DIR:-lib}/common.bash; }
[[ -z ${LIB_INSTALL_LOADED} ]] && { source ${LIB_DIR:-lib}/install.bash; }
LIB_GIT_LOADED=1

git_current_commit_message() {
  check_command git || install_sw git

  run_cmd git log --format=%B -n 1
}
