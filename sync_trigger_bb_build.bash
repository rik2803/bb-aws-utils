#! /bin/bash

echo "### Starting $(basename "${0}") ###"

scriptdir=$(dirname "${0}")
source ${scriptdir}/lib.bash

install_jq
 
[[ -z ${REMOTE_REPO_SLUG} ]]  && { echo "REMOTE_REPO_SLUG is required"; exit 1; }
[[ -z ${REMOTE_REPO_OWNER} ]] && { echo "REMOTE_REPO_OWNER is required"; exit 1; }
[[ -z ${BB_USER} ]]           && { echo "BB_USER is required"; exit 1; }
[[ -z ${BB_APP_PASSWORD} ]]   && { echo "BB_APP_PASSWORD is required"; exit 1; }

create_TAG_file_in_remote_url

start_pipeline_for_remote_repo ${REMOTE_REPO_COMMIT_HASH} ${2:-build_and_deploy}
[[ ${RETURNVALUE} == "SUCCESSFUL" ]] && exit 0
exit 1
