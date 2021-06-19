[[ -z ${LIB_COMMON_LOADED} ]] && { source "${LIB_DIR:-lib}/common.bash"; }
export LIB_DOCKER_LOADED=1

docker_build() {
  check_envvar DOCKER_IMAGE R
  check_envvar DOCKER_TAG R
  check_envvar AWS_ECR_ACCOUNTID R

  local dockerfile

  [[ -e docker/Dockerfile ]] && dockerfile="docker/Dockerfile"
  [[ -e ./Dockerfile ]] && dockerfile="./Dockerfile"
  [[ -z "${dockerfile}" ]] && fail 'No Dockerfile found in ./ or ./docker'

  # Build the image
  docker build --build-arg="BITBUCKET_COMMIT=${BITBUCKET_COMMIT:-NA}" \
               --build-arg="BITBUCKET_REPO_SLUG=${BITBUCKET_REPO_SLUG:-NA}" \
               --build-arg="BITBUCKET_REPO_OWNER=${BITBUCKET_REPO_OWNER:-NA}" \
               --tag "${AWS_ECR_ACCOUNTID}.dkr.ecr.${AWS_REGION:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}:${DOCKER_TAG}" \
               --file "${dockerfile}" \
               . \
    || fail "${FUNCNAME[0]} - An error occurred while building ${DOCKER_IMAGE}. Exiting ..."

  # Push the image
  docker push "${AWS_ECR_ACCOUNTID}.dkr.ecr.${AWS_REGION:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}:${DOCKER_TAG}"
}

docker_generate_dockerfile() {
  echo "FROM ${DOCKER_IMAGE}:$(cat TAG)" > Dockerfile

  if [[ -e ./Dockerfile.template ]]; then
    info "Evaluating Dockerfile.template to add to Dockerfile"
    sh -c 'echo "'"$(cat Dockerfile.template)"'"' >> Dockerfile
    debug "Content of generated Dockerfile - START"
    is_debug_enabled && cat Dockerfile
    debug "Content of generated Dockerfile - END"
  fi
}