source ${LIB_DIR:-lib}/common.bash

git_current_commit_message() {
  check_command git

  run_cmd git log --format=%B -n 1
}
