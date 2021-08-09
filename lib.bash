#!/usr/bin/env bash

CW_ALARMS_DISABLED=0
CW_ALARMS=NA

### Always load the complete library (including lib/*)
[[ -z ${LIB_DIR} ]] && LIB_DIR="./bb-aws-utils/lib"
# shellcheck source=lib/load.bash
[[ -e ${LIB_DIR}/load.bash ]] && source ${LIB_DIR}/load.bash

### To make sure everything keeps working after February 1 (see
### https://community.atlassian.com/t5/Bitbucket-Pipelines-articles/Pushing-back-to-your-repository/ba-p/958407)
### we explicitly set the repo origin to ${BITBUCKET_GIT_SSH_ORIGIN} unless the envvar ${BB_USE_HTTP_ORIGIN}
### is set
if [[ -n ${BB_USE_HTTP_ORIGIN} ]]
then
  git remote set-url origin "${BITBUCKET_GIT_HTTP_ORIGIN}"
else
  git remote set-url origin "${BITBUCKET_GIT_SSH_ORIGIN}"
fi

repo_git_url() {
  echo "git@bitbucket.org:${REMOTE_REPO_OWNER}/${REMOTE_REPO_SLUG}.git"
}

create_TAG_file_in_remote_url() {
  # To make sure the deploy pipeline uses the correct docker image tag,
  # this functions:
  #   - clones the remote repo
  #   - creates or updates a file named TAG in the root of the repo
  #   - the TAG file contains the commit hash of the SW git repo commit
  #   - adds, commits and pushes the changes
  # The pipeline of the config repo will then use the content of the file
  # to determine the tag of the docker image to pull and use to create
  # the deploy image.
  #
  # This requires that pipeline have an SSH key:
  #   bb -> repo -> settings -> pipelines -> SSH keys
  #
  # That ssh key should be granted read/write permissions to the repo
  # to be cloned, changed, committed and pushed, and will be available
  # as ~/.ssh/id_rsa

  ### It's useless to do this if no ssh key is configured in the pipeline.
  if [[ ! -e /opt/atlassian/pipelines/agent/data/id_rsa ]]
  then
    error "${FUNCNAME[0]} - ERROR: No SSH Key is configured in the pipeline, and this is required"
    error "${FUNCNAME[0]} -        to be able to add/update the TAG file in the remote (config)  "
    error "${FUNCNAME[0]} -        repository.                                                   "
    error "${FUNCNAME[0]} -        Add a key to the repository and try again.                    "
    error "${FUNCNAME[0]} -            bb -> repo -> settings -> pipelines -> SSH keys           "
    fail "Add a private SSH Key to the BB repository's pipeline settings"
  fi

  info "${FUNCNAME[0]} - REL_PREFIX:       ${REL_PREFIX:-NA}"
  info "${FUNCNAME[0]} - RC_PREFIX:        ${RC_PREFIX:-NA}"
  info "${FUNCNAME[0]} - BITBUCKET_TAG:    ${BITBUCKET_TAG:-NA}"
  info "${FUNCNAME[0]} - BITBUCKET_COMMIT: ${BITBUCKET_COMMIT:-NA}"

  ### Construct remote repo HTTPS URL
  REMOTE_REPO_URL=$(repo_git_url)
  info "${FUNCNAME[0]} - Remote repo URL is ${REMOTE_REPO_URL}"

  ### git config
  git config --global user.email "bitbucketpipeline@wherever.com"
  git config --global user.name "Bitbucket Pipeline"

    info "${FUNCNAME[0]} - Check what git user is being used"
    ssh git@bitbucket.org

  info "${FUNCNAME[0]} - Trying to clone ${REMOTE_REPO_URL} into remote_repo"
  rm -rf remote_repo
  git clone "${REMOTE_REPO_URL}" remote_repo || { echo "### ${FUNCNAME[0]} - Error cloning ${REMOTE_REPO_URL} ###"; exit 1; }

  run_log_and_exit_on_failure "cd remote_repo"

  info "${FUNCNAME[0]} - Update the TAG file in the repo"
  echo "${BITBUCKET_COMMIT}" > TAG
  git add TAG

  ### If 2 pipelines run on same commit, the TAG file will not change
  if ! git diff-index --quiet HEAD --
  then
    info "${FUNCNAME[0]} - TAG file was updated, committing and pushing the change"
    git commit -m 'Update TAG with source repo commit hash' || { echo "### ${FUNCNAME[0]} - Error committing TAG ###"; exit 1; }
    git push || { echo "### ${FUNCNAME[0]} - Error pushing to ${REMOTE_REPO_URL} ###"; exit 1; }
  elif [[ -n ${BITBUCKET_TAG} ]]
  then
    info "${FUNCNAME[0]} - TAG file was unchanged, because the pipeline for this commit has been run before."
    info "${FUNCNAME[0]} - BUT this build is triggered by a tag. Pipeline can continue"
  else
    info "${FUNCNAME[0]} - TAG file was unchanged, because the pipeline for this commit has been run before."
    info "${FUNCNAME[0]} - No further (git) actions required."
    if [[ -n ${ONLY_MONITOR_REMOTE_PIPELINE} ]] && [[ ${ONLY_MONITOR_REMOTE_PIPELINE} -eq 1 ]]
    then
      ### In this situation, a commit to the remote repository should trigger the build,
      ### but since the TAG file was not changed, a build will not be triggered, and the
      ### monitor_automatic_remote_pipeline_start will monitor a build that will never start.
      ### To solve this, we force the TAG to change by setting a dummy content and
      ### Committing with [skip ci] in the commit message.
      ### The next step is to change the TAG again and commit with a normal message.

      info "${FUNCNAME[0]} - Forcing the TAG to change by changing it twice."
      echo "FORCE REBUILD" > TAG
      git commit -m "[skip ci] Forcing a build on the next commit" TAG
      git push
      echo "${BITBUCKET_COMMIT}" > TAG
      git add TAG
      git commit -m 'Update TAG with source repo commit hash' || { echo "### ${FUNCNAME[0]} - Error committing TAG ###"; exit 1; }
      git push || { echo "### ${FUNCNAME[0]} - Error pushing to ${REMOTE_REPO_URL} ###"; exit 1; }
    fi
  fi

  ### If this build is triggered by a git tag, also put the tag on the config repo
  if [[ -n ${BITBUCKET_TAG} ]]
  then
    info "${FUNCNAME[0]} - This build is triggered by a tag, also put the tag ${BITBUCKET_TAG} on the config repo"
    info "${FUNCNAME[0]} - ${REMOTE_REPO_URL}"
    info "${FUNCNAME[0]} - To allow multiple builds of the config repo pipeline for the remote tag, the tag"
    info "${FUNCNAME[0]} - will first be removed to make sure the trigger is triggered."

    if git tag | grep -q "${BITBUCKET_TAG}"
    then
      info "${FUNCNAME[0]} - Tag ${BITBUCKET_TAG} already exists, removing it locally and remotely."
      git tag -d "${BITBUCKET_TAG}"
      git push --delete origin "${BITBUCKET_TAG}"
    fi

    echo "${FUNCNAME[0]} - Setting tag ${BITBUCKET_TAG} on HEAD and pushing to origin."
    git tag "${BITBUCKET_TAG}"
    git push --tags
  fi

  REMOTE_REPO_COMMIT_HASH=$(git rev-parse HEAD)
  info "${FUNCNAME[0]} - Full commit hash of remote repo is ${REMOTE_REPO_COMMIT_HASH}"

  run_log_and_exit_on_failure "cd -"
}

monitor_automatic_remote_pipeline_start() {
  ### This function is used to monitor the pipeline build that was automatically triggered
  ### by a commit or by adding a tag in create_TAG_file_in_remote_url. This is a requirement
  ### to make release candidate/release process work.
  ### The choice between starting the remote pipeline build or monitoring the remote
  ### pipeline build is made by setting the environment variable MONITOR_REMOTE_PIPELINE:
  ###    - envvar ONLY_MONITOR_REMOTE_PIPELINE is set and has value 1: use this function
  ###    - envvar ONLY_MONITOR_REMOTE_PIPELINE is not set or has value 0: trigger the remote
  ###      pipeline
  ### That envvar is evaluated in the script sync_trigger_bb_build.bash script

  info "${FUNCNAME[0]} - INFO - Entering ${FUNCNAME[0]}"
  export URL="https://api.bitbucket.org/2.0/repositories/${REMOTE_REPO_OWNER}/${REMOTE_REPO_SLUG}/pipelines/?pagelen=1&sort=-created_on"

  typeset -i MAX_TRIES=30
  typeset -i CUR_TRIES=0

  local STATE

  while [[ 1 -eq 1 ]]
  do
    if [[ ${CUR_TRIES} -eq ${MAX_TRIES} ]]
    then
      fail "${FUNCNAME[0]} - Quit waiting for remote pipeline to start, exiting ..."
    fi

    ### Get latest remote build info until status is pending, that indicates a newly started build
    STATE=$(curl -X GET -s -u "${BB_USER}:${BB_APP_PASSWORD}" -H 'Content-Type: application/json' "${URL}" | jq --raw-output '.values[0].state.name')
    if [[ ${STATE} == PENDING ]] || [[ ${STATE} == IN_PROGRESS ]]
    then
      info "${FUNCNAME[0]} - INFO - Remote pipeline is in PENDING state, continue to monitor it."
      break
    else
      info "${FUNCNAME[0]} - INFO - Remote pipeline state is ${STATE}, probably not a recent build, wait."
      info " ${FUNCNAME[0]} -        until state is PENDING or IN_PROGRESS ..."
      sleep 2
    fi
    (( CUR_TRIES=CUR_TRIES+1 )) || true
  done

  info "${FUNCNAME[0]} - Retrieve information about the most recent remote pipeline."
  CURL_RESULT=$(curl -X GET -s -u "${BB_USER}:${BB_APP_PASSWORD}" -H 'Content-Type: application/json' "${URL}")

  UUID=$(echo "${CURL_RESULT}" | jq --raw-output '.values[0].uuid' | tr -d '\{\}')
  BUILDNUMBER=$(echo "${CURL_RESULT}" | jq --raw-output '.values[0].build_number' | tr -d '\{\}')

  monitor_running_pipeline
}

start_pipeline_for_remote_repo() {
  ### See comments in monitor_automatic_remote_pipeline_start

  echo "${FUNCNAME[0]} - INFO - Entering ${FUNCNAME[0]}"

  REMOTE_REPO_COMMIT_HASH=${1}
  local PATTERN=${2:-build_and_deploy}

  URL="https://api.bitbucket.org/2.0/repositories/${REMOTE_REPO_OWNER}/${REMOTE_REPO_SLUG}/pipelines/"

  echo ""
  info "${FUNCNAME[0]} - REMOTE_REPO_OWNER:       ${REMOTE_REPO_OWNER}"
  info "${FUNCNAME[0]} - REMOTE_REPO_SLUG:        ${REMOTE_REPO_SLUG}"
  info "${FUNCNAME[0]} - URL:                     ${URL}"
  info "${FUNCNAME[0]} - REMOTE_REPO_COMMIT_HASH: ${REMOTE_REPO_COMMIT_HASH}"

  cat > /curldata << EOF
{
  "target": {
    "commit": {
      "hash":"${REMOTE_REPO_COMMIT_HASH}",
      "type":"commit"
    },
    "selector": {
      "type":"custom",
      "pattern":"${PATTERN}"
    },
    "type":"pipeline_commit_target"
  }
}
EOF

  CURL_RESULT=$(curl -X POST -s -u "${BB_USER}:${BB_APP_PASSWORD}" -H 'Content-Type: application/json' \
                    "${URL}" -d '@/curldata')

  UUID=$(echo "${CURL_RESULT}" | jq --raw-output '.uuid' | tr -d '\{\}')
  BUILDNUMBER=$(echo "${CURL_RESULT}" | jq --raw-output '.build_number')

  if [[ ${UUID} = "null" ]]
  then
    info "${FUNCNAME[0]} - ERROR: An error occurred when triggering the pipeline"
    info "${FUNCNAME[0]} -        for ${REMOTE_REPO_SLUG}"
    info "${FUNCNAME[0]} - Curl data and return object follow"
    cat /curldata
    info "***"
    echo "${CURL_RESULT}" | jq .
    exit 1
  fi

  monitor_running_pipeline
}

monitor_running_pipeline() {

  URL="https://api.bitbucket.org/2.0/repositories/${REMOTE_REPO_OWNER}/${REMOTE_REPO_SLUG}/pipelines/"

  info "${FUNCNAME[0]} - Remote pipeline is started and has UUID is ${UUID}"
  info "${FUNCNAME[0]} - Build UUID: ${UUID}"
  info "${FUNCNAME[0]} - Build Number: ${BUILDNUMBER}"
  info "***"
  info "${FUNCNAME[0]} - Link to the remote pipeline result is:"
  info "${FUNCNAME[0]} -   https://bitbucket.org/${REMOTE_REPO_OWNER}/${REMOTE_REPO_SLUG}/addon/pipelines/home#!/results/${BUILDNUMBER}"

  local CONTINUE=1
  local SLEEP=10
  local STATE="NA"
  local RESULT="na"
  local CURL_RESULT="NA"

  info "${FUNCNAME[0]} - Monitoring remote pipeline with UUID ${UUID} with interval ${SLEEP}"

  while [[ ${CONTINUE} = 1 ]]
  do
    sleep ${SLEEP}
    CURL_RESULT=$(curl -X GET -s -u "${BB_USER}:${BB_APP_PASSWORD}" -H 'Content-Type: application/json' ${URL}\\{${UUID}\\})
    STATE=$(echo "${CURL_RESULT}" | jq --raw-output ".state.name")

    info "  Pipeline is in state ${STATE}"

    if [[ ${STATE} == "COMPLETED" ]]
    then
      CONTINUE=0
    fi
  done

  RESULT=$(echo "${CURL_RESULT}" | jq --raw-output '.state.result.name')
  info "${FUNCNAME[0]} - Pipeline result is ${RESULT}"

  RETURNVALUE="${RESULT}"
}

set_credentials() {
  if [[ ${SERVICE_ACCOUNT} -eq 0 ]]; then
    local access_key=${1}
    local secret_key=${2}
    info "${FUNCNAME[0]} - Setting environment for AWS authentication"
    AWS_ACCESS_KEY_ID="${access_key}"
    AWS_SECRET_ACCESS_KEY="${secret_key}"
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
  else
    info "${FUNCNAME[0]} - Service account is being used, skipping set_credentials"
  fi
}

ecr_login() {
  local account_id="${1}"
  local region="${2}"
  local docker_server="${account_id}.dkr.ecr.${region:-eu-central-1}.amazonaws.com"
  info "Logging into ECR ${docker_server}"

  install_awscli

  info "Skipping aws ecr login because docker-credential-ecr-login is used for authentication"
  return 0

  if aws ecr get-login-password \
           --region "${region:-eu-central-1}" | \
               docker login \
                 --username AWS \
                 --password-stdin "${docker_server}"; then
    success "Successfully logged in to ${docker_server}"
  else
    fail "Error logging in to ${docker_server}, exiting ..."
  fi
}

set_source_ecr_credentials() {
  set_credentials "${AWS_ACCESS_KEY_ID_ECR_SOURCE}" "${AWS_SECRET_ACCESS_KEY_ECR_SOURCE}"
  info "${FUNCNAME[0]} - Logging in to AWS ECR source"
  if [[ -z ${AWS_ACCOUNTID_SRC} ]]; then
    info "Skip ECR login because AWS_ACCOUNTID_SRC is not set."
    info "This typically means that the source image is on docker hub and will be fetched from there."
  else
    ecr_login "${AWS_ACCOUNTID_SRC}" "${AWS_REGION_SOURCE:-eu-central-1}"
  fi
}

set_dest_ecr_credentials() {
  if [[ ${SERVICE_ACCOUNT} -eq 0 ]]; then
    info "${FUNCNAME[0]} - Fallback to AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY if AWS_ACCESS_KEY_ID_ECR_TARGET or AWS_SECRET_ACCESS_KEY_ECR_TARGET are not defined"
    [[ -z ${AWS_ACCESS_KEY_ID_ECR_TARGET} ]] && [[ -n ${AWS_ACCESS_KEY_ID} ]] && AWS_ACCESS_KEY_ID_ECR_TARGET=${AWS_ACCESS_KEY_ID}
    [[ -z ${AWS_SECRET_ACCESS_KEY_ECR_TARGET} ]] && [[ -n ${AWS_SECRET_ACCESS_KEY} ]] && AWS_SECRET_ACCESS_KEY_ECR_TARGET=${AWS_SECRET_ACCESS_KEY}
  fi
  set_credentials "${AWS_ACCESS_KEY_ID_ECR_TARGET}" "${AWS_SECRET_ACCESS_KEY_ECR_TARGET}"
  if [[ -z ${AWS_ACCOUNTID_TARGET} ]]; then
    fail "Unable to login to ECR because AWS_ACCOUNTID_TARGET is not set"
  else
    ecr_login "${AWS_ACCOUNTID_TARGET}" "${AWS_REGION_SOURCE:-eu-central-1}"
  fi
}

docker_build() {
  ### Use this function to build a docker artefact image from a source code repository
  local MYDIR

  ### Check for required parameters
  [[ -z ${AWS_ACCOUNTID_TARGET} ]]  && [[ -z ${AWS_ECR_ACCOUNTID} ]] && fail "${FUNCNAME[0]} - One of AWS_ACCOUNTID_TARGET or AWS_ECR_ACCOUNTID is required"
  [[ -z ${DOCKER_IMAGE} ]]          && fail "${FUNCNAME[0]} - DOCKER_IMAGE is required"
  if [[ ${SERVICE_ACCOUNT} -eq 0 ]]; then
    [[ -z ${AWS_ACCESS_KEY_ID} ]]     && fail "${FUNCNAME[0]} - AWS_ACCESS_KEY_ID is required"
    [[ -z ${AWS_SECRET_ACCESS_KEY} ]] && fail "${FUNCNAME[0]} - AWS_SECRET_ACCESS_KEY is required"
  fi

  ### Use AWS_ECR_ACCOUNTID if AWS_ACCOUNTID_TARGET is not defined
  if [[ -z ${AWS_ACCOUNTID_TARGET} ]]
  then
    info "${FUNCNAME[0]} - AWS_ACCOUNTID_TARGET not set, use AWS_ECR_ACCOUNTID instead (${AWS_ECR_ACCOUNTID})"
    AWS_ACCOUNTID_TARGET=${AWS_ECR_ACCOUNTID}
  else
    info "${FUNCNAME[0]} - AWS_ACCOUNTID_TARGET set, using it (${AWS_ACCOUNTID_TARGET})"
  fi

  ecr_login "${AWS_ACCOUNTID_TARGET}" "${AWS_REGION_SOURCE:-eu-central-1}"

  ### The Dockerfile is supposed to be in a subdirectory docker of the repo
  MYDIR=$(pwd)
  if [[ -e /${BITBUCKET_CLONE_DIR}/docker/Dockerfile ]]
  then
    cd "/${BITBUCKET_CLONE_DIR}/docker" || fail "Directory /${BITBUCKET_CLONE_DIR}/docker does not exist, Exiting ..."
  elif [[ -e /${BITBUCKET_CLONE_DIR}/Dockerfile ]]
  then
    cd "/${BITBUCKET_CLONE_DIR}" || fail "Directory /${BITBUCKET_CLONE_DIR} does not exist, Exiting ..."
  else
    info "${FUNCNAME[0]} - ERROR - No dockerfile found where expected (/${BITBUCKET_CLONE_DIR}/docker/Dockerfile or"
    info "${FUNCNAME[0]} - /${BITBUCKET_CLONE_DIR}/Dockerfile. Exiting ..."
    exit 1
   fi

  info "{FUNCNAME[0]} - Start build of docker image ${DOCKER_IMAGE}"
  _docker_build "${DOCKER_IMAGE}"

  info "${FUNCNAME[0]} - Tagging docker image ${DOCKER_IMAGE}:${BITBUCKET_COMMIT}"
  docker tag "${DOCKER_IMAGE}" "${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}"
  docker tag "${DOCKER_IMAGE}" "${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}:${BITBUCKET_COMMIT}"

  info "${FUNCNAME[0]} - Pushing docker image ${DOCKER_IMAGE}:${BITBUCKET_COMMIT} to ECR"
  docker push "${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}"
  docker push "${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}:${BITBUCKET_COMMIT}"

  if [[ -n ${BITBUCKET_TAG} ]] && [[ -n ${RC_PREFIX} ]] && [[ ${BITBUCKET_TAG} = ${RC_PREFIX}* ]]
  then
    info "${FUNCNAME[0]} - Building a release candidate, also add the ${BITBUCKET_TAG} tag on the docker image"
    docker tag "${DOCKER_IMAGE}" "${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}:${BITBUCKET_TAG}"
    docker push "${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}:${BITBUCKET_TAG}"
  fi

  cd "${MYDIR}" || fail "Directory ${MYDIR} does not exist, Exiting ..."
}

docker_build_application_image() {
  info "${FUNCNAME[0]} - Docker info:"
  docker info
  info "${FUNCNAME[0]} - Start build of docker image ${DOCKER_IMAGE}"
  _docker_build "${DOCKER_IMAGE}"
}

docker_build_deploy_image() {
  echo "${FUNCNAME[0]} - Determine the TAG to use for the docker pull from the file named TAG."
  export TAG="latest"

  local SOURCE_IMAGE
  local IMAGE_REPOSITORY

  info "${FUNCNAME[0]} - Create deploy Dockerfile"
  info "${FUNCNAME[0]} -    - use the content of the TAG file as the label for the docker image"
  info "${FUNCNAME[0]} -      to build FROM, unless ...."
  info "${FUNCNAME[0]} -    - REL_PREFIX is defined and RC_PREFIX is defined and the BITBUCKET_TAG"
  info "${FUNCNAME[0]} -      being built starts with REL_PREFIX. This indicates a production"
  info "${FUNCNAME[0]} -      build that should use the corresponding ACC build (with a RC tag)"
  info "***"
  info "${FUNCNAME[0]} - REL_PREFIX:       ${REL_PREFIX:-NA}"
  info "${FUNCNAME[0]} - RC_PREFIX:        ${RC_PREFIX:-NA}"
  info "${FUNCNAME[0]} - BITBUCKET_TAG:    ${BITBUCKET_TAG:-NA}"
  info "${FUNCNAME[0]} - BITBUCKET_COMMIT: ${BITBUCKET_COMMIT:-NA}"

  if [[ -n ${BITBUCKET_TAG} ]] && [[ -n ${RC_PREFIX} ]] && [[ -n ${REL_PREFIX} ]] && [[ ${BITBUCKET_TAG} = ${REL_PREFIX}* ]]
  then
    TAG=${RC_PREFIX}${BITBUCKET_TAG##${REL_PREFIX}}
    info "${FUNCNAME[0]} - Building a release, use the release candidate artefact image with tag ${TAG}"
  else
    [[ -e TAG ]] && TAG=$(cat TAG)
    info "${FUNCNAME[0]} - Not a release build, use artefact image with tag ${TAG}"
  fi

  # Check if required image exists in the repository by pulling it and failing if pull fails
  #   To support images in docker hub, the image is pulled from docker hub when the envvar
  #   AWS_ACCOUNTID_SRC is not defined
  if [[ -z ${AWS_ACCOUNTID_SRC} ]]; then
    warning "Envvar AWS_ACCOUNTID_SRC not set, assuming source image is in Docker Hub."
    SOURCE_IMAGE="${DOCKER_IMAGE}:${TAG:-latest}"
    IMAGE_REPOSITORY="Docker Hub"
  else
    SOURCE_IMAGE="${AWS_ACCOUNTID_SRC}.dkr.ecr.${AWS_REGION_SOURCE:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}:${TAG:-latest}"
    IMAGE_REPOSITORY="${AWS_ACCOUNTID_SRC}.dkr.ecr.${AWS_REGION_SOURCE:-eu-central-1}.amazonaws.com."
  fi

  if ! docker pull "${SOURCE_IMAGE}"
  then
    _print_error_banner
    error "${FUNCNAME[0]} - ERROR - The docker image ${DOCKER_IMAGE}:${TAG:-latest} is not available"
    error "${FUNCNAME[0]}           on repository ${IMAGE_REPOSITORY}"
    error "${FUNCNAME[0]}           Possible causes:"
    error "${FUNCNAME[0]}             - This is a production deploy and the build on ACC was not done"
    error "${FUNCNAME[0]}             - The image was deleted on ECR"
    error "${FUNCNAME[0]}             - A bug in this project"
    error "${FUNCNAME[0]}           Fix the issue and retry"
    fail "${FUNCNAME[0]}           Exiting ..."
  fi

  echo "FROM ${SOURCE_IMAGE}" > Dockerfile

  if [[ -e Dockerfile.template ]]; then
    echo "### ${FUNCNAME[0]} INFO: evaluating Dockerfile.template to add to Dockerfile"
    sh -c 'echo "'"$(cat Dockerfile.template)"'"' >> Dockerfile
    echo "### ${FUNCNAME[0]} INFO: Dockerfile content - START"
    cat Dockerfile
    echo "### ${FUNCNAME[0]} INFO: Dockerfile content - END"
  fi

  # Allow to add extra files to the docker image. The envvar should be constructed like
  # this: "src1:dst1 src2:dst2". This will result in these lines being added to the
  # Dockerfile file:
  # ADD src1 dst1
  # ADD src2 dst2
  if [[ -n ${FILES_TO_ADD_TO_DOCKER_IMAGE} ]]; then
    for SRC_COLON_DEST in ${FILES_TO_ADD_TO_DOCKER_IMAGE}; do
      echo "ADD ${SRC_COLON_DEST%%:*} ${SRC_COLON_DEST##*:}" >> Dockerfile
    done
  fi

  IMAGE=${DOCKER_IMAGE}

  if [[ -n ${DOCKER_IMAGE_TARGET} ]]
  then
    ### Possibility to override target image
    IMAGE=${DOCKER_IMAGE_TARGET}
  fi

  info "${FUNCNAME[0]} - Start build of docker image ${IMAGE}-${ENVIRONMENT:-dev} based on the artefact image with tag ${TAG:-latest}"
  _docker_build "${IMAGE}-${ENVIRONMENT:-dev}"
}

docker_tag_and_push_deploy_image() {
  IMAGE=${DOCKER_IMAGE}

  if [[ -n ${DOCKER_IMAGE_TARGET} ]]
  then
    ### Possibility to override target image
    IMAGE=${DOCKER_IMAGE_TARGET}
  fi

  info "${FUNCNAME[0]} - Tagging docker image ${IMAGE}-${ENVIRONMENT:-dev}"
  docker tag "${IMAGE}-${ENVIRONMENT:-dev}" "${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${IMAGE}-${ENVIRONMENT:-dev}"
  info "${FUNCNAME[0]} - Pushing docker image ${IMAGE}-${ENVIRONMENT:-dev} to ECR."
  docker push "${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${IMAGE}-${ENVIRONMENT:-dev}"
}

docker_tag_and_push_application_image() {
  [[ -z ${AWS_ACCOUNTID_TARGET} ]] && { echo "### ${FUNCNAME[0]} - AWS_ACCOUNTID_TARGET envvar is required ###"; exit 1; }
  [[ -z ${DOCKER_IMAGE} ]]         && { echo "### ${FUNCNAME[0]} - DOCKER_IMAGE envvar is required ###"; exit 1; }

  info "${FUNCNAME[0]} - Tagging docker image ${DOCKER_IMAGE}"
  docker tag "${DOCKER_IMAGE}" "${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}"
  docker tag "${DOCKER_IMAGE}" "${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}:${BITBUCKET_COMMIT}"
  info "${FUNCNAME[0]} - Pushing docker image ${DOCKER_IMAGE} to ECR."
  docker push "${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}"
  docker push "${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}:${BITBUCKET_COMMIT}"
}

docker_deploy_image() {
  if [[ -n ${CW_ALARM_SUBSTR} ]]
  then
    info "${FUNCNAME[0]} - Disable all CloudWatch alarm actions to avoid panic reactions."
    _disable_cw_alarms
  fi

  # ECS_SERVICE can be a comma separated list of services, to support
  # the case where the same image is used by 2 services (i.e external and
  # internal)
  for service in ${ECS_SERVICE//,/ }
  do
    info "${FUNCNAME[0]} - Force update service ${service} on ECS cluster ${ECS_CLUSTER} in region ${AWS_REGION}"
    run_log_and_exit_on_failure "aws ecs update-service --cluster ${ECS_CLUSTER} --force-new-deployment --service ${service} --region ${AWS_REGION:-eu-central-1}"
  done

  if [[ -n ${CW_ALARM_SUBSTR} ]]
  then
    info "${FUNCNAME[0]} - Allow the service to stabilize before re-enabling alarms (120 seconds)."
    sleep 30
    info " ${FUNCNAME[0]} -    90 seconds remaining."
    sleep 30
    info "${FUNCNAME[0]} -    60 seconds remaining."
    sleep 30
    info "${FUNCNAME[0]} -    30 seconds remaining."
    sleep 30
    info "${FUNCNAME[0]} - Enable all CloudWatch alarm actions to guarantee the services being monitored."
    _enable_cw_alarms
  fi
}

s3_deploy_apply_config_to_tree() {
  # In all files under ${basedir}, replace all occurrences of __VARNAME__ to the value of
  # the environment variable CFG_VARNAME, for all envvars starting with CFG_
  local basedir
  local SUBST_SRC
  local SUBST_VAL

  basedir=${1}

  for VARNAME in ${!CFG_*}
  do
    SUBST_SRC="__${VARNAME##CFG_}__"
    SUBST_VAL=$(eval echo \$${VARNAME})
    info "${FUNCNAME[0]} - Replacing all occurrences of ${SUBST_SRC} to ${SUBST_VAL} in all files under ${basedir}"
    for file in $(find ${basedir} -type f); do
      sed -i "s|${SUBST_SRC}|${SUBST_VAL}|g" "${file}"
    done
  done
}

s3_deploy_create_tar_and_upload_to_s3() {
  info "${FUNCNAME[0]} - Create tar file ${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz from all files in ${PAYLOAD_LOCATION:-dist}"
  tar -C "${PAYLOAD_LOCATION:-dist}" -czvf "${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz" .
  info "${FUNCNAME[0]} - Copy ${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz to S3 bucket ${S3_ARTIFACT_BUCKET}/${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz"
  aws s3 cp --quiet "${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz" "s3://${S3_ARTIFACT_BUCKET}/${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz"
  info " ${FUNCNAME[0]} - Copy ${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz to S3 bucket ${S3_ARTIFACT_BUCKET}/${ARTIFACT_NAME}-last.tgz"
  aws s3 cp --quiet "${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz" "s3://${S3_ARTIFACT_BUCKET}/${ARTIFACT_NAME}-last.tgz"
}

s3_deploy_download_tar_and_prepare_for_deploy() {
  TAG="last"
  [[ -e TAG ]] && TAG=$(cat TAG)

  info "${FUNCNAME[0]} - Download artifact ${ARTIFACT_NAME}-${TAG}.tgz from s3://${S3_ARTIFACT_BUCKET}"
  aws s3 cp --quiet "s3://${S3_ARTIFACT_BUCKET}/${ARTIFACT_NAME}-${TAG}.tgz" .
  info "${FUNCNAME[0]} - Create workdir ###"
  mkdir -p workdir
  info "### ${FUNCNAME[0]} - Untar the artifact file into the workdir.#"
  cd workdir || fail "Directory workdir does not exist. Exiting ..."
  tar -xzvf "../${ARTIFACT_NAME}-${TAG}.tgz"
  cd ..
  info "${FUNCNAME[0]} - Start applying the config to the untarred files."
  s3_deploy_apply_config_to_tree workdir
}

s3_deploy_deploy() {
  install_awscli
  cd "${1:-workdir}" || fail "Directory ${1:-workdir} does not exist. Exiting ..."

  if [[ ${SERVICE_ACCOUNT} -eq 0 ]]; then
    info "${FUNCNAME[0]} - Set AWS credentials for deploy (AWS_ACCESS_KEY_ID_S3_TARGET and AWS_SECRET_ACCESS_KEY_S3_TARGET)."
    set_credentials "${AWS_ACCESS_KEY_ID_S3_TARGET}" "${AWS_SECRET_ACCESS_KEY_S3_TARGET}"
  fi
  info "${FUNCNAME[0]} - Deploy the payload to s3://${S3_DEST_BUCKET}/${S3_PREFIX:-} with ACL ${AWS_ACCESS_CONTROL:-private}"
  aws s3 cp --quiet --acl "${AWS_ACCESS_CONTROL:-private}" --recursive . "s3://${S3_DEST_BUCKET}/${S3_PREFIX:-}"
  cd - || fail "Previous (cd -) directory does not exist. Exiting ..."
}

s3_deploy() {
  install_awscli

  if [[ ${SERVICE_ACCOUNT} -eq 0 ]]; then
    info "${FUNCNAME[0]} - Set AWS credentials for artifact download (AWS_ACCESS_KEY_ID_S3_SOURCE and AWS_SECRET_ACCESS_KEY_S3_SOURCE)."
    set_credentials "${AWS_ACCESS_KEY_ID_S3_SOURCE}" "${AWS_SECRET_ACCESS_KEY_S3_SOURCE}"
  fi

  s3_deploy_download_tar_and_prepare_for_deploy
  info "${FUNCNAME[0]} - Start the deploy."
  s3_deploy_deploy
  s3_cloudfront_invalidate
}

s3_lambda_build_and_push() {

  ### Required for all types of Lambda build
  [[ -z ${S3_DEST_BUCKET} ]]        && fail "${FUNCNAME[0]} - S3_DEST_BUCKET envvar is required"
  if [[ ${SERVICE_ACCOUNT} -eq 0 ]]; then
    [[ -z ${AWS_ACCESS_KEY_ID} ]]     && fail "${FUNCNAME[0]} - AWS_ACCESS_KEY_ID envvar is required"
    [[ -z ${AWS_SECRET_ACCESS_KEY} ]] && fail "${FUNCNAME[0]} - AWS_SECRET_ACCESS_KEY envvar is required"
  fi
  [[ -z ${LAMBDA_RUNTIME} ]]        && fail "${FUNCNAME[0]} - LAMBDA_RUNTIME envvar is required"
  [[ -z ${LAMBDA_FUNCTION_NAME} ]]  && fail "${FUNCNAME[0]} - LAMBDA_FUNCTION_NAME envvar is required"

  ### Setup
  export CI=false
  install_awscli
  install_zip
  run_log_and_exit_on_failure "mkdir -p /builddir"

  ### Copy extra stuff to builddir
  if [[ -n ${LAMBDA_COPY_TO_BUILDDIR} ]]; then
    for file in ${LAMBDA_COPY_TO_BUILDDIR}; do
      run_log_and_exit_on_failure "cp -rp ${file} /builddir"
    done
  fi

  ### Java8
  if [[ ${LAMBDA_RUNTIME} = java* ]]
  then
    ### These envvars are required, exit 1 if not
    [[ -z ${JAR_FILE} ]]       && { echo "### ${FUNCNAME[0]} - JAR_FILE envvar is required ###"; exit 1; }
    [[ -z ${BUILD_COMMAND} ]]  && { echo "### ${FUNCNAME[0]} - BUILD_COMMAND envvar is required ###"; exit 1; }
    run_log_and_exit_on_failure "${BUILD_COMMAND}"
  fi

  ### Node
  if [[ ${LAMBDA_RUNTIME} = nodejs* ]]
  then
    create_npmrc
    if [[ -n ${NESTJS} ]]; then
      # https://keyholesoftware.com/2019/05/13/aws-lambda-with-nestjs/
      if [[ -n ${DEBUG} ]]; then
        run_log_and_exit_on_failure "npm install"
      else
        run_log_and_exit_on_failure "npm install --silent"
      fi
      run_log_and_exit_on_failure "npm run build"
      run_log_and_exit_on_failure "npm prune --production"
      run_log_and_exit_on_failure "mv -f dist node_modules /builddir"
    else
      [[ -e ${LAMBDA_FUNCTION_FILE:-index.js} ]] && run_log_and_exit_on_failure "mv -f ${LAMBDA_FUNCTION_FILE:-index.js} /builddir"
      [[ -e ${LAMBDA_FUNCTION_DIR:-dist} ]] && run_log_and_exit_on_failure "cp -rp ${LAMBDA_FUNCTION_DIR:-dist}/* /builddir"
      if [[ -f package.json ]]
      then
        if [[ -n ${DEBUG} ]]; then
          run_log_and_exit_on_failure "npm install"
        else
          run_log_and_exit_on_failure "npm install --silent"
        fi
        run_log_and_exit_on_failure "npm prune --production"
        [[ -e node_modules ]] && run_log_and_exit_on_failure "mv -f node_modules /builddir"
      fi
    fi
  fi

  ### Python
  if [[ ${LAMBDA_RUNTIME} = python* ]]; then
    [[ -e ${LAMBDA_FUNCTION_FILE:-lambda.py} ]] && run_log_and_exit_on_failure "mv -f ${LAMBDA_FUNCTION_FILE:-lambda.py} /builddir"
    # DIRS_TO_ADD_TO_ZIP is a space separated list of directories that will be copied to
    # builddir and be part of the function zip file
    if [[ -n ${DIRS_TO_ADD_TO_ZIP} ]]; then
      for dir in ${DIRS_TO_ADD_TO_ZIP}; do
        info "${FUNCNAME[0]} - Copying ${dir} to /builddir"
        run_log_and_exit_on_failure "cp -rp ${dir} /builddir"
      done
    fi
    if [[ -n ${FILES_TO_ADD_TO_ZIP} ]]; then
      for file in ${FILES_TO_ADD_TO_ZIP}; do
        echo "### ${FUNCNAME[0]} - Copying ${file} to /builddir ###"
        run_log_and_exit_on_failure "cp -rp ${file} /builddir"
      done
    fi

    if [[ -n ${CICD_REQUIREMENTS} && -f ${CICD_REQUIREMENTS} ]]; then
        echo "### ${FUNCNAME[0]} - CICD requirements file ${CICD_REQUIREMENTS} found, using this file to build dependencies ###"
        run_log_and_exit_on_failure "pip install -r ${CICD_REQUIREMENTS} --target /builddir"
    elif [[ -f requirements.txt ]]; then
      if [[ -z ${SKIP_PIP_INSTALL} || ${SKIP_PIP_INSTALL} -eq 0 ]]; then
        run_log_and_exit_on_failure "pip install --quiet --target /builddir -r requirements.txt"
      else
        info "${FUNCNAME[0]} - Skipped dependency build because SKIP_PIP_INSTALL is set to ${SKIP_PIP_INSTALL}"
      fi
    fi
    echo "### ${FUNCNAME[0]} - Remove boto stuff from the installed dependencies ###"
    run_log_and_exit_on_failure "rm -rf /builddir/boto* || true"
  fi

  ### Upload the Lambda artifact to S3
  local TARGETS
  local EXTENSION
  local SOURCE

  TARGETS=""

  if [[ ${LAMBDA_RUNTIME} = java* ]]
  then
    EXTENSION="jar"
    SOURCE="${JAR_PATH:-.}/${JAR_FILE}"
  else
    EXTENSION="zip"
    SOURCE="/${LAMBDA_FUNCTION_NAME}.zip"
    info "${FUNCNAME[0]} - Zip the Lambda code and dependencies."
    run_log_and_exit_on_failure "cd /builddir"
    run_log_and_exit_on_failure "zip -q -r /${LAMBDA_FUNCTION_NAME}.zip *"
    run_log_and_exit_on_failure "cd -"
  fi

  TARGETS="${TARGETS} ${LAMBDA_FUNCTION_NAME}.${EXTENSION}"
  TARGETS="${TARGETS} ${LAMBDA_FUNCTION_NAME}-${BITBUCKET_COMMIT}.${EXTENSION}"
  [[ -n ${BITBUCKET_TAG} ]] && TARGETS="${TARGETS} ${LAMBDA_FUNCTION_NAME}-${BITBUCKET_COMMIT}.${EXTENSION}"

  set_credentials "${AWS_ACCESS_KEY_ID}" "${AWS_SECRET_ACCESS_KEY}"

  for TARGET in ${TARGETS}
  do
    run_log_and_exit_on_failure "aws s3 cp --quiet --acl private ${SOURCE} s3://${S3_DEST_BUCKET}/${TARGET}"
    info "${FUNCNAME[0]} - S3 URL is https://s3.amazonaws.com/${S3_DEST_BUCKET}/${TARGET}"
  done

  if [[ -n ${LAMBDA_PUBLIC} ]] && [[ ${LAMBDA_PUBLIC} == 1 ]]
  then
    for TARGET in ${TARGETS}
    do
      run_log_and_exit_on_failure "aws s3 cp --quiet --acl public-read ${SOURCE} s3://${S3_DEST_BUCKET}-public/${TARGET}"
      info "${FUNCNAME[0]} - S3 URL is https://s3.amazonaws.com/${S3_DEST_BUCKET}-public/${TARGET}"
    done
  fi
}

s3_artifact() {
  install_awscli
  info "${FUNCNAME[0]} - Run the build command (${BUILD_COMMAND:-No build command})."
  if [[ -n ${BUILD_COMMAND} ]]
  then
    create_npmrc
    eval "${BUILD_COMMAND}"
  fi

  if [[ ${SERVICE_ACCOUNT} -eq 0 ]]; then
    info "${FUNCNAME[0]} - Set AWS credentials for artifact upload (AWS_ACCESS_KEY_ID_S3_TARGET and AWS_SECRET_ACCESS_KEY_S3_TARGET)."
  fi
  set_credentials "${AWS_ACCESS_KEY_ID_S3_TARGET}" "${AWS_SECRET_ACCESS_KEY_S3_TARGET}"

  s3_deploy_create_tar_and_upload_to_s3
}

create_npmrc() {
  info "${FUNCNAME[0]} - Create ~/.npmrc file for NPMJS authentication."
  echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN:-NA}" > ~/.npmrc
}

clone_repo() {
  ### Construct remote repo HTTPS URL
  REMOTE_REPO_URL=$(repo_git_url)

  info "${FUNCNAME[0]} - Remote repo URL is ${REMOTE_REPO_URL}"

  ### git config
  git config --global user.email "bitbucketpipeline@wherever.com"
  git config --global user.name "Bitbucket Pipeline"

  info "${FUNCNAME[0]} - Trying to clone ${REMOTE_REPO_URL} into remote_repo."
  run_log_and_exit_on_failure "rm -rf remote_repo"
  run_log_and_exit_on_failure "git clone --single-branch -b ${REMOTE_REPO_BRANCH:-master} ${REMOTE_REPO_URL} remote_repo"

  run_log_and_exit_on_failure "cd remote_repo"
  if [[ -n ${BITBUCKET_TAG} ]]
  then
    info "${FUNCNAME[0]} - Build is triggered by a tag, checkout the remote repos tag ${BITBUCKET_TAG}"
    info "${FUNCNAME[0]} - instead of commit hash in the TAG file."
    run_log_and_exit_on_failure "git checkout ${BITBUCKET_TAG}"
  else
    run_log_and_exit_on_failure "git checkout $(cat ../TAG)"
  fi

  run_log_and_exit_on_failure "cd -"
}

s3_cloudfront_invalidate() {
  if [[ -n ${CLOUDFRONT_DISTRIBUTION_ID} ]]
  then
    run_log_and_exit_on_failure "aws cloudfront create-invalidation --distribution-id ${CLOUDFRONT_DISTRIBUTION_ID} --paths '/*'"
  else
    info "${FUNCNAME[0]} - WARNING: Skipping cloudfront invalidation because CLOUDFRONT_DISTRIBUTION_ID is not set."
  fi
}

s3_build_once_deploy_once() {
  ### This is for legacy stuff and Q&D pipeline migrations
  ###   * clone a repository REMOTE_REPO_SLUG for REMOTE_REPO_OWNER and branch REMOTE_REPO_BRANCH (default is master)
  ###   * run the BUILD_COMMAND
  ###   * copy all files in PAYLOAD_LOCATION (default is dist) to s3://${S3_DEST_BUCKET}/${S3_PREFIX:-} with ACL ${AWS_ACCESS_CONTROL:-private}
  ###   * invalidate the CloudFront Distribution CLOUDFRONT_DISTRIBUTION_ID
  ### For S3 authentication: AWS_ACCESS_KEY_ID_S3_TARGET and AWS_SECRET_ACCESS_KEY_S3_TARGET
  ### Use SSH private key to be able to clone the repository

  clone_repo
  ### clone_repo clones in the remote_repo directory
  run_log_and_exit_on_failure "cd remote_repo"
  run_log_and_exit_on_failure "${BUILD_COMMAND}"

  if [[ ${SERVICE_ACCOUNT} -eq 0 ]]; then
    info "${FUNCNAME[0]} - Set AWS credentials for deploy (AWS_ACCESS_KEY_ID_S3_TARGET and AWS_SECRET_ACCESS_KEY_S3_TARGET)."
  fi
  set_credentials "${AWS_ACCESS_KEY_ID_S3_TARGET}" "${AWS_SECRET_ACCESS_KEY_S3_TARGET}"

  info "${FUNCNAME[0]} - Start the deploy."
  install_awscli
  s3_deploy_deploy "${PAYLOAD_LOCATION}"
  s3_cloudfront_invalidate

  run_log_and_exit_on_failure "cd -"
}

#####################
### Private functions

_disable_cw_alarms() {
  local line

  true > alarms_to_enable.txt
  aws cloudwatch describe-alarms \
    --region "${AWS_REGION:-eu-central-1}" \
    --query "MetricAlarms[*]|[?contains(AlarmName, '${CW_ALARM_SUBSTR}')].[AlarmName,ActionsEnabled]" \
    --output text | \
  while read -r line
  do
    set -- ${line}
    if [[ ${2} == "True" ]]
    then
      info "${FUNCNAME[0]} - INFO - Disabling alarm ${1}"
      aws cloudwatch disable-alarm-actions --region "${AWS_REGION:-eu-central-1}" --alarm-names "${1}"
      echo "${1}" >> alarms_to_enable.txt
    fi
  done
  CW_ALARMS_DISABLED=1
}

_enable_cw_alarms() {
  for ALARM in $(cat alarms_to_enable.txt)
  do
    info "${FUNCNAME[0]} - INFO - Enabling alarm ${ALARM}"
    aws cloudwatch enable-alarm-actions --region "${AWS_REGION:-eu-central-1}" --alarm-names "${ALARM}"
  done
  CW_ALARMS_DISABLED=0
  rm -f alarms_to_enable.txt
}

_docker_build() {
  local image_name

  image_name=${1:-${DOCKER_IMAGE}}

  [[ -z ${image_name} ]] && { echo "### ${FUNCNAME[0]} - DOCKER_IMAGE is required ###"; exit 1; }

  info "${FUNCNAME[0]} - Start build of docker image ${DOCKER_IMAGE}"
  if [[ -e /opt/atlassian/pipelines/agent/data/id_rsa ]]; then
    info "${FUNCNAME[0]} - The private ssh key file exists, passing its contents as docker build arg.#"
    docker build --build-arg="BITBUCKET_COMMIT=${BITBUCKET_COMMIT:-NA}" \
                 --build-arg="BITBUCKET_REPO_SLUG=${BITBUCKET_REPO_SLUG:-NA}" \
                 --build-arg="BITBUCKET_REPO_OWNER=${BITBUCKET_REPO_OWNER:-NA}" \
                 --build-arg="SSH_PRIV_KEY=$(cat /opt/atlassian/pipelines/agent/data/id_rsa)" \
                 -t "${image_name}" \
                 . \
    || fail "${FUNCNAME[0]} - An error occurred while building ${DOCKER_IMAGE}. Exiting ..."
  else
    info "${FUNCNAME[0]} - The private ssh key file does not exist."
    docker build --build-arg="BITBUCKET_COMMIT=${BITBUCKET_COMMIT:-NA}" \
                 --build-arg="BITBUCKET_REPO_SLUG=${BITBUCKET_REPO_SLUG:-NA}" \
                 --build-arg="BITBUCKET_REPO_OWNER=${BITBUCKET_REPO_OWNER:-NA}" \
                 -t "${image_name}" \
                 . \
    || fail "${FUNCNAME[0]} - An error occurred while building ${DOCKER_IMAGE}. Exiting ..."
  fi
}

_print_error_banner() {
  error '  ______ _____  _____   ____  _____  '
  error ' |  ____|  __ \|  __ \ / __ \|  __ \ '
  error ' | |__  | |__) | |__) | |  | | |__) |'
  error ' |  __| |  _  /|  _  /| |  | |  _  / '
  error ' | |____| | \ \| | \ \| |__| | | \ \ '
  error ' |______|_|  \_\_|  \_\\____/|_|  \_\'
  error '                                     '
}
