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
#   remote_repo_slug (required): The slug of the repo to start a pipeline for
#   pattern (default: build_and_deploy): The "pattern" of the pipeline to start on the remote repo. Can be the name
#       of a branch when the fourth argument (remote_repo_selector_type) is "branch", or the name of a custom
#       pipeline if remote_repo_selector_type is absent.
#   remote_repo_branch: If present, start the pipeline on a branch. If absent, start the pipeline o the commit hash
#       of the remote branch determined by the envvar REMOTE_REPO_COMMIT_HASH
#   remote_repo_selector_type: Should be "branch" is the remote pipeline is to start on the branch determined by
#       remote_repo_branch
#   build_variables: A list of variables to pass to the remote pipeline. The format is "key1=value1;key2=value2"
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
  local remote_repo_selector_type
  local build_variables
  local build_variables_json

  info "${FUNCNAME[0]} - Entering ${FUNCNAME[0]}"

  check_envvar BB_USER R
  check_envvar BB_APP_PASSWORD R

  install_jq

  remote_repo_slug="${1}"
  pattern="${2:-build_and_deploy}"
  remote_repo_branch="${3:-}"
  remote_repo_selector_type="${4:-custom}"
  build_variables="${5:-}" # format is key1=value1;key2=value2

  # Format build variables into json
  if [[ -n "${build_variables}" ]]; then
    build_variables_json="["
    for var in $(echo "${build_variables}" | tr ';' '\n'); do
      build_variables_json="${build_variables_json} {\"key\": \"$(echo "${var}" | cut -d '=' -f 1)\", \"value\": \"$(echo "${var}" | cut -d '=' -f 2)\"},"
    done
    build_variables_json=$(echo "${build_variables_json}]" | sed 's/,]/]/')
  else
    build_variables_json="[]"
  fi

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
  },
  "variables": ${build_variables_json}
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
#######################################
# This function will check if the file config/versions.json has been changed
# If it has, it will commit and push the changes
#
_bb_push_file_if_changed() {

  local file
  local extra_commit_string
  local version
  local jira_issue
  local branch_name
  local clone_path

  file="${1}"
  extra_commit_string="${2:-NA}"
  version="${3:-NA}"
  jira_issue="${4}"
  branch_name="${5}"
  clone_path="${6}"

  _bb_retry_push() {
      git reset HEAD~ || { warning "Failed during git reset"; return 1; }
      git stash || { warning "Failed during git stash"; return 1; }
      git pull || { warning "Failed during git pull"; return 1; }
      git stash pop || { warning "Failed during git stash pop"; return 1; }
      git commit -m "${jira_issue} ${extra_commit_string} ${version}" "${file}" || { warning "Failed during git commit"; return 1; }
      git push origin "${branch_name}" || { warning "Failed during git push"; return 1; }
      return 0
  }

  git_set_user_config

  cd "${clone_path}"

  if git diff --exit-code "${file}" >/dev/null 2>&1; then
      info "No changes, skipping commit"
  else
    info "File changed, committing and pushing ..."
    git commit -m "${jira_issue} ${extra_commit_string} ${version}" "${file}"
    info "Trying to push changes ..."
    if ! git push origin "${branch_name}"; then
      warning "Push failed, trying a second time ..."
      if ! _bb_retry_push "${jira_issue}" "${branch_name}" "${version}"; then
        warning "First retry failed, trying a third time ..."
        _bb_retry_push "${jira_issue}" "${branch_name}" "${version}"
      fi
    fi
  fi

  cd -
}

#######################################
# This function is used to clone another repo and create a branch that matches the branch of the
# repo in which the pipeline is running.
#
# If the branch of the current repo is `master` or `main`, the branch creation will be skipped.
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
_bb_clone_and_branch_repo() {
  local repo_slug
  local jira_issue_regex
  local git_result

  git_set_user_config

  repo_slug="${1}"
  branch_to_create_if_on_master_or_main="${2:-}"

  jira_issue_regex="^feature/[A-Z]+-[0-9]+"

  if [[ -n ${branch_to_create_if_on_master_or_main} ]]; then
    BB_CLONE_AND_BRANCH_REPO_BRANCH_NAME="${branch_to_create_if_on_master_or_main}"
  else
    BB_CLONE_AND_BRANCH_REPO_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  fi

  BB_CLONE_AND_BRANCH_REPO_JIRA_ISSUE=$(echo "${BB_CLONE_AND_BRANCH_REPO_BRANCH_NAME}" | grep -Eo "${jira_issue_regex}" | sed 's/feature\///')
  BB_CLONE_AND_BRANCH_REPO_CLONE_PATH="/${repo_slug}"
  info "Cloning ${repo_slug} into ${BB_CLONE_AND_BRANCH_REPO_CLONE_PATH}"
  git clone "git@bitbucket.org:${BITBUCKET_WORKSPACE}/${repo_slug}.git" "${BB_CLONE_AND_BRANCH_REPO_CLONE_PATH}"
  cd "${BB_CLONE_AND_BRANCH_REPO_CLONE_PATH}"

  info "Checking if branch ${BB_CLONE_AND_BRANCH_REPO_BRANCH_NAME} exists in ${repo_slug}."
  git_result=$(git ls-remote --heads git@bitbucket.org:${BITBUCKET_WORKSPACE}/${repo_slug}.git ${BB_CLONE_AND_BRANCH_REPO_BRANCH_NAME})
  if [[ -z ${git_result} ]]; then
    info "Branch ${BB_CLONE_AND_BRANCH_REPO_BRANCH_NAME} does not exist yet. Creating it."
    git checkout -b ${BB_CLONE_AND_BRANCH_REPO_BRANCH_NAME}
  else
    info "Branch ${BB_CLONE_AND_BRANCH_REPO_BRANCH_NAME} already exists. Checking it out."
    git checkout ${BB_CLONE_AND_BRANCH_REPO_BRANCH_NAME}
  fi

  check_envvar BB_CLONE_AND_BRANCH_REPO_JIRA_ISSUE R
  check_envvar BB_CLONE_AND_BRANCH_REPO_BRANCH_NAME R
  check_envvar BB_CLONE_AND_BRANCH_REPO_CLONE_PATH R

  cd -
}

#######################################
# This function is used to bump the service version in the aws-cdk project.
#
# Expects:
#   AWS_CDK_PROJECT: The CDK project to bump the version in
#   SERVICE_NAME: The name of the service to bump the version for
#
# Expects:
#  branch_to_create_if_on_master_or_main (optional): If the branch is master or main, this branch will be created
#    and checked out by _bb_clone_and_branch_repo. If not, a branch with the name of the current branch will be created.
#
# Globals:
#
# Arguments:
#
# Returns:
#
#######################################
bb_bump_service_version_in_awscdk_project() {
  check_envvar AWS_CDK_PROJECT R
  check_envvar SERVICE_NAME R

  local project_version
  local version_to_bump_to
  local branch_to_create_if_on_master_or_main

  branch_to_create_if_on_master_or_main="${1:-}"
  info "${FUNCNAME[0]} - Entering ${FUNCNAME[0]}"

  info "Retrieving project version ..."
  project_version=$(mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version -q -DforceStdout && mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
  info "Project version: ${project_version}"

  info "If branch is master or main, use RELEASE_VERSION as version to bump to, otherwise use ${BITBUCKET_COMMIT}-${project_version}"
  if [[ "${BITBUCKET_BRANCH}" == "master" || "${BITBUCKET_BRANCH}" == "main" ]]; then
    info "Branch is master or main, using RELEASE_VERSION as version to bump to"
    check_envvar RELEASE_VERSION R
    [[ -n ${branch_to_create_if_on_master_or_main} ]] || fail "branch_to_create_if_on_master_or_main required but not passed in function bb_bump_service_version_in_awscdk_project"
    version_to_bump_to="${RELEASE_VERSION}"
  else
    info "Branch is not master or main, using ${BITBUCKET_COMMIT}-${project_version} as version to bump to"
    version_to_bump_to="${BITBUCKET_COMMIT}-${project_version}"
  fi

  install_jq
  _bb_clone_and_branch_repo "${AWS_CDK_PROJECT}" "${branch_to_create_if_on_master_or_main}"

  cd -
  info "Changing version of service ${SERVICE_NAME} to ${version_to_bump_to} in config/versions.json"
  jq ".serviceVersions.${SERVICE_NAME} = \"${version_to_bump_to}\"" config/versions.json > config/versions.json.tmp && mv config/versions.json.tmp config/versions.json
  cd -

  _bb_push_file_if_changed "config/versions.json" "Bump ${SERVICE_NAME} to " "${version_to_bump_to}" "${BB_CLONE_AND_BRANCH_REPO_JIRA_ISSUE}" "${BB_CLONE_AND_BRANCH_REPO_BRANCH_NAME}" "${BB_CLONE_AND_BRANCH_REPO_CLONE_PATH}"
}

#######################################
# This function is used to bump the config label in the aws-cdk project.
#
# Expects:
#   AWS_CDK_PROJECT: The CDK project to bump the version in
#
# Expects:
#  branch_to_create_if_on_master_or_main (optional): If the branch is master or main, this branch will be created
#    and checked out by _bb_clone_and_branch_repo. If not, a branch with the name of the current branch will be created.
# Globals:
#
# Arguments:
#
# Returns:
#
#######################################
bb_bump_config_label_in_awscdk_project() {
  check_envvar AWS_CDK_PROJECT R

  local config_label
  local branch_to_create_if_on_master_or_main

  branch_to_create_if_on_master_or_main="${1:-}"
  info "${FUNCNAME[0]} - Entering ${FUNCNAME[0]}"

  info "Retrieving config label."
  config_label=$(git tag --points-at HEAD | tail -1)
  info "Config Label: ${config_label}"

  install_jq
  _bb_clone_and_branch_repo "${AWS_CDK_PROJECT}" "${branch_to_create_if_on_master_or_main}"

  cd -
  info "Changing config label to ${config_label} in config/versions.json"
  jq ".configLabel = \"${config_label}\"" config/versions.json > config/versions.json.tmp && mv config/versions.json.tmp config/versions.json
  cd -

  _bb_push_file_if_changed "config/versions.json" "Bump config label to " "${config_label}" "${BB_CLONE_AND_BRANCH_REPO_JIRA_ISSUE}" "${BB_CLONE_AND_BRANCH_REPO_BRANCH_NAME}" "${BB_CLONE_AND_BRANCH_REPO_CLONE_PATH}"
}

bb_start_and_monitor_build_pipeline() {

  local target_repo_slug
  local target_pipeline
  local target_branch

  local repo_url
  local branch_url
  local latest_build_url
  local build_statuses_url

  local response_body
  local latest_build_status

  check_envvar BB_USER R
  check_envvar BB_APP_PASSWORD R
  check_envvar BUILD_TYPE R
  check_envvar BITBUCKET_BRANCH R

  [[ -n ${1} ]] && target_repo_slug=${1} || fail "target_repo_slug required"
  if  [[ "${BUILD_TYPE}" == "RELEASE" ]]; then

    target_pipeline="release_deploy"
    target_branch="master"
  else

    target_pipeline="snapshot_deploy"
    target_branch="${BITBUCKET_BRANCH}"
  fi

  install_jq

  repo_url="https://api.bitbucket.org/2.0/repositories/${BITBUCKET_REPO_OWNER}/${target_repo_slug}"
  info "Checking repo URL ${repo_url}"
  curl --silent -u "${BB_USER}:${BB_APP_PASSWORD}" --location ${repo_url}

  if ([[ "${BUILD_TYPE}" == "RELEASE" ]] && latest_commit_message_starts_with ${target_repo_slug} "Merged in ${target_branch}") || \
     ([[ "${BUILD_TYPE}" == "SNAPSHOT" ]] && bb_branch_exists_in_repo ${target_repo_slug} ${target_branch});
  then

    branch_url=${repo_url}/refs/branches/${target_branch}
    response_body=$(curl --silent -u "${BB_USER}:${BB_APP_PASSWORD}" --location ${branch_url})

    build_statuses_url=$(echo "${response_body}" | jq --raw-output '.target.links.statuses.href')
    response_body=$(curl --fail --silent -u "${BB_USER}:${BB_APP_PASSWORD}" --location ${build_statuses_url}?sort=-created_on)

    latest_build_status=$(echo "${response_body}" | jq  --raw-output '.values[0].state')
    latest_build_url=$(echo "${response_body}" | jq  --raw-output '.values[0].url')

    info "Latest build for branch ${target_branch}: ${latest_build_url}"

    if [[ ${latest_build_status} == "SUCCESSFUL" ]]; then
      info "Latest build for branch ${target_branch} was successful, skipping..."
    else
      info "Latest build for branch ${target_branch} was not successful (status = ${latest_build_status}), triggering pipeline ${target_pipeline}"
      bb_start_pipeline_for_repo ${target_repo_slug} ${target_pipeline} ${target_branch} "custom" "AWS_CDK_BRANCH_TO_BUMP=${BITBUCKET_BRANCH}"
      bb_monitor_running_pipeline ${target_repo_slug}
    fi

  fi
}

latest_commit_message_starts_with() {
  local repo_slug
  local branch_name
  local prefix
  local response_body
  local last_message

  [[ -n ${1} ]] && repo_slug=${1} || fail "repo_slug required"
  [[ -n ${2} ]] && branch_name=${2} || fail "branch_name required"
  [[ -n ${3} ]] && prefix=${3} || fail "prefix required"

  branch_url="https://api.bitbucket.org/2.0/repositories/${BITBUCKET_REPO_OWNER}/${repo_slug}/refs/branches/${branch_name}"
  response_body=$(curl --silent -u "${BB_USER}:${BB_APP_PASSWORD}" --location ${branch_url})

  last_message=$(echo "${response_body}" | jq --raw-output '.target.message')

  info "Checking whether commit message ${last_message} starts with ${prefix}"

  [[ "${last_message}" == "${prefix}"* ]]
}

#######################################
# This function is used to check if the given branch exists in a repo.
#
# Expects:
#   repo_slug: The repo slug to check the branch for
#   branch_name: The branch name to check for
#
# Globals:
#
# Arguments:
#
# Returns:
#   - 0 if the branch exists
#   - 1 if it doesn't
#
#######################################
bb_branch_exists_in_repo() {

  local repo_slug
  local branch_name

  [[ -n ${1} ]] && repo_slug=${1} || fail "repo_slug required"
  [[ -n ${2} ]] && branch_name=${2} || fail "branch_name required"

  if git ls-remote --exit-code --heads "git@bitbucket.org:ixorcvba/${repo_slug}.git" "${branch_name}"; then
    info "Branch ${branch_name} exists for repo ${repo_slug}"
    return 0
  else
    info "Branch ${branch_name} does not exist for repo ${repo_slug}"
    return 1
  fi
}

