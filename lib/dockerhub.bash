source ./common.bash

dockerhub_login() {
  check_envvar DOCKERHUB_USERNAME R
  check_envvar DOCKERHUB_PASSWORD R

  run_cmd docker login --username="${DOCKERHUB_USERNAME}" --password="${DOCKERHUB_PASSWORD}"
}
