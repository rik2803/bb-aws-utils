# shellcheck source=../../bb-aws-utils/lib/common.bash
[[ -z ${LIB_COMMON_LOADED} ]]  && { source "${LIB_DIR:-lib}/common.bash"; }
# shellcheck source=../../bb-aws-utils/lib/git.bash
[[ -z ${LIB_GIT_LOADED} ]]     && { source "${LIB_DIR:-lib}/git.bash"; }
# shellcheck source=../../bb-aws-utils/lib/install.bash
[[ -z ${LIB_INSTALL_LOADED} ]] && { source "${LIB_DIR:-lib}/install.bash"; }

export LIB_BITBUCKET_LOADED=1

bb_set_repo_origin() {
  ### To make sure everything keeps working after February 1 (see
  ### https://community.atlassian.com/t5/Bitbucket-Pipelines-articles/Pushing-back-to-your-repository/ba-p/958407)
  ### we explicitly set the repo origin to ${BITBUCKET_GIT_SSH_ORIGIN} unless the envvar ${BB_USE_HTTP_ORIGIN}
  ### is set
  if [[ -n ${BB_USE_HTTP_ORIGIN} ]]
  then
    info "Set origin to BITBUCKET_GIT_HTTP_ORIGIN"
    cd "${BITBUCKET_CLONE_DIR}" && git remote set-url origin "${BITBUCKET_GIT_HTTP_ORIGIN}" && cd -
  else
    info "Set origin to BITBUCKET_GIT_SSH_ORIGIN"
    cd "${BITBUCKET_CLONE_DIR}" && git remote set-url origin "${BITBUCKET_GIT_SSH_ORIGIN}" && cd -
  fi
}

# Copy the pipeline private key to a given destination (or current directory by default)
bb_cp_ssh_privkey() {
  local priv_key_location="/opt/atlassian/pipelines/agent/ssh/id_rsa"

  if [[ -e ${priv_key_location} ]]; then
    info "Repo has a private key in ${priv_key_location}, copying to ${1:-.}."
    cp -f "${priv_key_location}" "${1:-.}"
    if [[ -d "${1:-.}" ]]; then
      chmod 0600 "${1:-.}/id_rsa"
    else
      chmod 0600 "${1}/id_rsa"
    fi
  else
    fail "No private SSH key is configured for this repo. Failing because you seem to rely on it. Bye bye."
  fi
}

bb_fail_if_no_private_ssh_key() {
  if [[ ! -e /opt/atlassian/pipelines/agent/data/id_rsa ]]
  then
    error "${FUNCNAME[0]} - ERROR: No SSH Key is configured in the pipeline, and this is required"
    error "${FUNCNAME[0]} -        to be able to add/update the TAG file in the remote (config)  "
    error "${FUNCNAME[0]} -        repository.                                                   "
    error "${FUNCNAME[0]} -        Add a key to the repository and try again.                    "
    error "${FUNCNAME[0]} -            bb -> repo -> settings -> pipelines -> SSH keys           "
    fail "Add a private SSH Key to the BB repository's pipeline settings"
  fi

  return 0
}

bb_printenv() {
  info "${FUNCNAME[0]} - REL_PREFIX:       ${REL_PREFIX:-NA}"
  info "${FUNCNAME[0]} - RC_PREFIX:        ${RC_PREFIX:-NA}"
  info "${FUNCNAME[0]} - BITBUCKET_TAG:    ${BITBUCKET_TAG:-NA}"
  info "${FUNCNAME[0]} - BITBUCKET_COMMIT: ${BITBUCKET_COMMIT:-NA}"
}

bb_get_config_repo_url() {
  echo "git@bitbucket.org:${BITBUCKET_REPO_OWNER}/${1}.git"
}

bb_is_config_repo() {
#  [[ ${BITBUCKET_REPO_SLUG} = *\.config\.* ]] && echo slugoke
#  [[ -e "${BITBUCKET_CLONE_DIR}/TAG" ]] && echo tagoke
  if [[ ${BITBUCKET_REPO_SLUG} = *\.config\.* ]]; then
    return 0
  else
    return 1
  fi
}

bb_print_user() {
  info "${FUNCNAME[0]} - Check what git user is being used"
  ssh git@bitbucket.org
}

#######################################
# Update the TAG file in the config repository for a given environment (tst/stg/prd).
#
# To make sure the deploy pipeline uses the correct docker image tag,
# this functions:
#   - clones the config repo for the environment
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
#
# Expects:
#
# Globals:
#
# Arguments:
#
# Returns:
#
#######################################
bb_update_tag_in_config_repo() {
  git_set_user_config
  bb_fail_if_no_private_ssh_key
  is_debug_enabled && bb_printenv
  is_debug_enabled && bb_print_user

  local remote_repo_url
  local remote_repo_slug
  local remote_repo_dir

  remote_repo_slug="${1}"
  remote_repo_url=$(bb_get_config_repo_url "${remote_repo_slug}")
  remote_repo_dir="remote_repo"

  git_clone_repo "${remote_repo_url}" "${remote_repo_dir}"
  cd "${remote_repo_dir}"
  info "${FUNCNAME[0]} - Update the TAG file in ${remote_repo_url}"
  echo "${BITBUCKET_COMMIT}" > TAG
  git add TAG
  git commit --allow-empty -m 'Update TAG with source repo commit hash' TAG || \
    fail "${FUNCNAME[0]} - Error committing TAG to ${remote_repo_url}"
  git push || fail "${FUNCNAME[0]} - Error pushing to ${remote_repo_url}"

  ### If this build is triggered by a git tag, also put the tag on the config repo
  if [[ -n ${BITBUCKET_TAG} ]]
  then
    info "${FUNCNAME[0]} - This build is triggered by a tag, also put the tag ${BITBUCKET_TAG} on the config repo"
    info "${FUNCNAME[0]} - ${remote_repo_url}"
    info "${FUNCNAME[0]} - To allow multiple builds of the config repo pipeline for the remote tag, the tag"
    info "${FUNCNAME[0]} - will first be removed to make sure the trigger is triggered."

    git_rm_tag "${BITBUCKET_TAG}"
    git_set_tag "${BITBUCKET_TAG}"
  fi

  # REMOTE_REPO_COMMIT_HASH is required to be able to start te pipeline on the remote repo in start_pipeline_for_repo
  REMOTE_REPO_COMMIT_HASH=$(git rev-parse HEAD)
  info "${FUNCNAME[0]} - Full commit hash of latest commit in remote repo ${remote_repo_url} is ${REMOTE_REPO_COMMIT_HASH}"

  cd -
  rm -rf "${remote_repo_dir}"
}

bb_sync_trigger_build() {
  local remote_repo_slug
  local custom_pipeline_pattern

  # ToDo: validation
  remote_repo_slug="${1}"
  custom_pipeline_pattern="${2:-build_and_deploy}"

  bb_update_tag_in_config_repo "${remote_repo_slug}"

  info "${FUNCNAME[0]} - ONLY_MONITOR_REMOTE_PIPELINE is ${ONLY_MONITOR_REMOTE_PIPELINE:-Not Defined} ###"
  if [[ -n ${ONLY_MONITOR_REMOTE_PIPELINE} ]] && [[ ${ONLY_MONITOR_REMOTE_PIPELINE} -eq 1 ]]
  then
    info "${FUNCNAME[0]} - Starting monitor_automatic_remote_pipeline_start."
    bb_wait_for_pipeline_status_pending_or_in_progress "${remote_repo_slug}"
    bb_monitor_running_pipeline "${remote_repo_slug}"
    success "${FUNCNAME[0]} - monitor_automatic_remote_pipeline_start finished."
  else
    info "${FUNCNAME[0]} - Starting start_pipeline_for_remote_repo."
    bb_start_pipeline_for_repo "${remote_repo_slug}" "${custom_pipeline_pattern}"
    bb_monitor_running_pipeline "${remote_repo_slug}"
    success "${FUNCNAME[0]} - start_pipeline_for_remote_repo finished."
  fi
}

#######################################
# This function is used to monitor the pipeline build that was automatically triggered
# by a commit or by adding a tag in create_TAG_file_in_remote_url. This is a requirement
# to make release candidate/release process work.
# The choice between starting the remote pipeline build or monitoring the remote
# pipeline build is made by setting the environment variable MONITOR_REMOTE_PIPELINE:
#    - envvar ONLY_MONITOR_REMOTE_PIPELINE is set and has value 1: use this function
#    - envvar ONLY_MONITOR_REMOTE_PIPELINE is not set or has value 0: trigger the remote
#      pipeline
# That envvar is evaluated in the script sync_trigger_bb_build.bash script
#
# Expects:
#
# Globals:
#
# Arguments:
#
# Returns:
#
#######################################
bb_wait_for_pipeline_status_pending_or_in_progress() {
  check_envvar BB_USER R
  check_envvar BB_APP_PASSWORD R

  info "Start waiting until pipeline status is PENDING or IN_PROGRESS"
  local rest_url
  local remote_repo_slug
  local max_tries
  local cur_tries
  local state
  local curl_result

  remote_repo_slug="${1}"
  max_tries=30
  cur_tries=0

  install_jq

  rest_url="https://api.bitbucket.org/2.0/repositories/${BITBUCKET_REPO_OWNER}/${remote_repo_slug}/pipelines/?pagelen=1&sort=-created_on"

  while true; do
        if [[ ${cur_tries} -ge ${max_tries} ]]
    then
      fail "${FUNCNAME[0]} - Quit waiting for remote pipeline to start after ${cur_tries} tries, exiting ..."
    fi

    ### Get latest remote build info until status is pending, that indicates a newly started build
    state=$(curl -X GET -s -u "${BB_USER}:${BB_APP_PASSWORD}" -H 'Content-Type: application/json' "${rest_url}" | jq --raw-output '.values[0].state.name')
    if [[ ${state} == PENDING ]] || [[ ${state} == IN_PROGRESS ]]
    then
      info "${FUNCNAME[0]} - Remote pipeline is in PENDING state, continue to monitor it."
      break
    else
      info "${FUNCNAME[0]} - Remote pipeline state is ${state}, probably not a recent build, waiting"
      info "${FUNCNAME[0]} -    until state is PENDING or IN_PROGRESS ..."
      sleep 2
    fi
    (( cur_tries=cur_tries+1 )) || true
  done

  info "${FUNCNAME[0]} - Retrieve information about the most recent remote pipeline."
  curl_result=$(curl -X GET -s -u "${BB_USER}:${BB_APP_PASSWORD}" -H 'Content-Type: application/json' "${rest_url}")
  UUID=$(echo "${curl_result}" | jq --raw-output '.values[0].uuid' | tr -d '\{\}')
  BUILD_NUMBER=$(echo "${curl_result}" | jq --raw-output '.values[0].build_number' | tr -d '\{\}')
}

bb_monitor_running_pipeline() {
  local rest_url
  local remote_repo_slug
  local continue
  local sleep
  local state=
  local result
  local curl_result

  check_envvar BB_USER R
  check_envvar BB_APP_PASSWORD R

  continue=1
  sleep=10
  state="NA"
  result="NA"
  curl_result="NA"
  remote_repo_slug="${1}"
  rest_url="https://api.bitbucket.org/2.0/repositories/${BITBUCKET_REPO_OWNER}/${remote_repo_slug}/pipelines/"

  info "${FUNCNAME[0]} - Remote pipeline is started:"
  info "${FUNCNAME[0]} - Build UUID: ${UUID}"
  info "${FUNCNAME[0]} - Build Number: ${BUILD_NUMBER}"
  info "***"
  info "${FUNCNAME[0]} - Link to the remote pipeline result is (CLICK TO FOLLOW!!):"
  info "${FUNCNAME[0]} -   https://bitbucket.org/${BITBUCKET_REPO_OWNER}/${remote_repo_slug}/addon/pipelines/home#!/results/${BUILD_NUMBER}"
  info "${FUNCNAME[0]} - Monitoring remote pipeline with UUID ${UUID} with interval ${sleep}"

  while [[ ${continue} = 1 ]]
  do
    sleep ${sleep}
    curl_result=$(curl -X GET -s -u "${BB_USER}:${BB_APP_PASSWORD}" -H 'Content-Type: application/json' ${rest_url}\\{${UUID}\\})
    state=$(echo "${curl_result}" | jq --raw-output ".state.name")

    info "  Pipeline is in state ${state}"

    if [[ ${state} == "COMPLETED" ]]
    then
      continue=0
    fi
  done

  result=$(echo "${curl_result}" | jq --raw-output '.state.result.name')
  info "${FUNCNAME[0]} - Pipeline result is ${result}"

  [[ ${result} = SUCCESSFUL ]] && return 0
  fail "${FUNCNAME[0]} - Remote pipeline finished with status ${result}."
}

#######################################
# This function is used to start a pipeline for another repository.
#
# Expects:
#   BB_USER: a Bitbucket user with pipeline start permissions on the remote repo
#   BB_APP_PASSWORD: the app password for BB_USER
#
# Globals:
#
# Arguments:
#   remote_repo_slug (required): The slug of the repo to start apipeline for
#   pattern (default: build_and_deploy): The "pattern" of the pipeline to start on the remote repo. Can be the name
#       of a branch when the fourth argument (remote_repo_selector_type) is "branch", or the name of a custom
#       pipeline if remote_repo_selector_type is absent.
#   remote_repo_branch: If present, start the pipeline on a branch. If absent, start the pipeline o the commit hash
#       of the remote branch determined by the envvar REMOTE_REPO_COMMIT_HASH
#   remote_repo_selector_type: Should be "branch" is the remote pipeline is to start on the branch determined by
#       remote_repo_branch
# Returns:
#
#######################################
bb_start_pipeline_for_repo() {
  ### See comments in monitor_automatic_remote_pipeline_start
  local rest_url
  local pattern
  local remote_repo_slug
  local curl_result
  local remote_repo_branch

  info "${FUNCNAME[0]} - Entering ${FUNCNAME[0]}"

  check_envvar BB_USER R
  check_envvar BB_APP_PASSWORD R

  install_jq

  remote_repo_slug="${1}"
  pattern="${2:-build_and_deploy}"
  remote_repo_branch="${3:-}"
  remote_repo_selector_type="${4:-custom}"

  rest_url="https://api.bitbucket.org/2.0/repositories/${BITBUCKET_REPO_OWNER}/${remote_repo_slug}/pipelines/"

  echo ""
  info "${FUNCNAME[0]} - BITBUCKET_REPO_OWNER:    ${BITBUCKET_REPO_OWNER}"
  info "${FUNCNAME[0]} - REMOTE_REPO_SLUG:        ${remote_repo_slug}"
  info "${FUNCNAME[0]} - URL:                     ${rest_url}"
  if [[ -n "${REMOTE_REPO_COMMIT_HASH}" ]]; then
    info "${FUNCNAME[0]} - REMOTE_REPO_COMMIT_HASH: ${REMOTE_REPO_COMMIT_HASH}"
  else
    if [[ -n "${remote_repo_branch}" ]]; then
      info "${FUNCNAME[0]} - remote_repo_branch:      ${remote_repo_branch}"
    fi
  fi

  cat > /curldata.commithash << EOF
{
  "target": {
    "commit": {
      "hash": "${REMOTE_REPO_COMMIT_HASH}",
      "type": "commit"
    },
    "selector": {
      "type": "custom",
      "pattern": "${pattern}"
    },
    "type":"pipeline_commit_target"
  }
}
EOF

  cat > /curldata.branch << EOF
{
  "target": {
    "ref_type": "branch",
    "type": "pipeline_ref_target",
    "ref_name": "${remote_repo_branch}",
    "selector": {
      "type": "${remote_repo_selector_type}",
      "pattern": "${pattern}"
    }
  }
}
EOF

  if [[ -n "${remote_repo_branch}" ]]; then
    cp /curldata.branch /curldata
  else
    cp /curldata.commithash /curldata
  fi

  curl_result=$(curl -X POST -s -u "${BB_USER}:${BB_APP_PASSWORD}" -H 'Content-Type: application/json' \
                    "${rest_url}" -d '@/curldata')

  UUID=$(echo "${curl_result}" | jq --raw-output '.uuid' | tr -d '\{\}')
  BUILD_NUMBER=$(echo "${curl_result}" | jq --raw-output '.build_number')

  if [[ ${UUID} = "null" ]]
  then
    error "${FUNCNAME[0]} - An error occurred when triggering the pipeline"
    error "${FUNCNAME[0]} -        for ${remote_repo_slug}"
    error "${FUNCNAME[0]} - Curl data and return object follow"
    cat /curldata
    error "***"
    echo "${curl_result}" | jq .
    fail "An error occurred when triggering the pipeline"
  fi
}

bb_start_and_monitor_pipeline_if_branch_exists() {

  local target_repo_slug
  local target_pipeline
  local target_branch

  local rest_url_base
  local response_body
  local build_statuses_url
  local latest_build_status
  local latest_build_url

  [[ -n ${1} ]] && target_repo_slug=${1} || fail "target_repo_slug required"
  [[ -n ${1} ]] && target_pipeline=${2} || fail "target_pipeline required"
  [[ -n ${1} ]] && target_branch=${3} || fail "target_branch required"

  check_envvar BB_USER R
  check_envvar BB_APP_PASSWORD R

  rest_url_base="https://api.bitbucket.org/2.0/repositories/${BITBUCKET_REPO_OWNER}/${target_repo_slug}"
  response_body=$(curl --fail --silent -u "${BB_USER}:${BB_APP_PASSWORD}" --location ${rest_url_base}/refs/branches/${target_branch})

  if [[ $? -eq 0 ]]; then
    info "Branch ${target_branch} exists for repo ${target_repo_slug}, checking build status..."
    build_statuses_url=$(echo "${response_body}" | jq --raw-output '.target.links.statuses.href')
    response_body=$(curl --fail --silent -u "${BB_USER}:${BB_APP_PASSWORD}" --location ${build_statuses_url}?sort=-created_on)

    latest_build_status=$(echo "${response_body}" | jq  --raw-output '.values[0].state')
    latest_build_url=$(echo "${response_body}" | jq  --raw-output '.values[0].url')

    info "Latest build for branch ${target_branch}: ${latest_build_url}"

    if [[ ${latest_build_status} == "SUCCESSFUL" ]]; then
      info "Latest build for branch ${target_branch} was successful, skipping..."
    else
      info "Latest build for branch ${target_branch} was not successful (status = ${latest_build_status}), triggering pipeline ${target_pipeline}"
      bb_start_pipeline_for_repo ${target_repo_slug} ${target_pipeline} ${target_branch}
      bb_monitor_running_pipeline ${target_repo_slug}
    fi
  else
    info "Branch ${target_branch} does not exist for repo ${target_repo_slug}, skipping this one"
  fi
}