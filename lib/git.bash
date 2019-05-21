source lib/common.bash

git_current_commit_message() {
  check_command git

  run git log --format=%B -n 1
}
