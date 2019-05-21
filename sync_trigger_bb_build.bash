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

echo "### sync_trigger_bb_build.bash - ONLY_MONITOR_REMOTE_PIPELINE is ${ONLY_MONITOR_REMOTE_PIPELINE:-Not Defined} ###"
if [[ -n ${ONLY_MONITOR_REMOTE_PIPELINE} ]] && [[ ${ONLY_MONITOR_REMOTE_PIPELINE} -eq 1 ]]
then
  echo "### sync_trigger_bb_build.bash - Starting monitor_automatic_remote_pipeline_start .... ###"
  monitor_automatic_remote_pipeline_start
  echo "### sync_trigger_bb_build.bash - monitor_automatic_remote_pipeline_start finished ###"
else
  echo "### sync_trigger_bb_build.bash - Starting start_pipeline_for_remote_repo .... ###"
  start_pipeline_for_remote_repo ${REMOTE_REPO_COMMIT_HASH} ${2:-build_and_deploy}
  echo "### sync_trigger_bb_build.bash - start_pipeline_for_remote_repo finished ###"
fi

[[ ${RETURNVALUE} == "SUCCESSFUL" ]] && exit 0
exit 1
