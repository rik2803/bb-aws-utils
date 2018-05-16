#! /bin/bash

echo "### Starting $(basename "${0}") ###"

scriptdir=$(dirname "${0}")
source ${scriptdir}/lib.bash

echo "### Start jq installation ###"
install_jq

### jq is required
if ! which jq >/dev/null 2>&1
then
  echo "### jq is required ###"
  exit 1
else
  echo "### jq is installed ###"
fi
 
[[ -z ${REMOTE_REPO_SLUG} ]]  && { echo "REMOTE_REPO_SLUG is required"; exit 1; }
[[ -z ${REMOTE_REPO_OWNER} ]] && { echo "REMOTE_REPO_OWNER is required"; exit 1; }
[[ -z ${BB_USER} ]]           && { echo "BB_USER is required"; exit 1; }
[[ -z ${BB_APP_PASSWORD} ]]   && { echo "BB_APP_PASSWORD is required"; exit 1; }

### Construct remote repo HTTPS URL
REMOTE_REPO_URL="https://${BB_USER}:${BB_APP_PASSWORD}@bitbucket.org/${REMOTE_REPO_OWNER}/${REMOTE_REPO_OWNER}"

echo "### Trying to clone ${REMOTE_REPO_URL} into remote_repo ###"
git clone ${REMOTE_REPO_URL} remote_repo || { echo "### Error cloning ${REMOTE_REPO_URL} ###"; exit 1; }
echo "### Update the TAG file in the repor ###"
echo "${BITBUCKET_COMMIT}" > remote_repo/TAG
cd remote_repo
git commit -m 'Update TAG with source repo commit hash' TAG || { echo "### Error committing TAG ###"; exit 1; }
git push || { echo "### Error pushing to ${REMOTE_REPO_URL} ###"; exit 1; }
cd -

export URL="https://api.bitbucket.org/2.0/repositories/${REMOTE_REPO_OWNER}/${REMOTE_REPO_SLUG}/pipelines/"

echo "### REMOTE_REPO_OWNER: ${REMOTE_REPO_OWNER} ###"
echo "### REMOTE_REPO_SLUG:  ${REMOTE_REPO_SLUG} ###"
echo "### URL:               ${URL} ###"

CURLRESULT=$(curl -X POST -s -u "${BB_USER}:${BB_APP_PASSWORD}" -H 'Content-Type: application/json' \
                  ${URL} -d '{ "target": { "ref_type": "branch", "type": "pipeline_ref_target", "ref_name": "master" } }')

UUID=$(echo "${CURLRESULT}" | jq --raw-output '.uuid' | tr -d '\{\}')

echo "UUID is ${UUID}"

CONTINUE=1
SLEEP=10
STATE="NA"
RESULT="na"
CURLRESULT="NA"

while [[ ${CONTINUE} = 1 ]]
do
  sleep ${SLEEP}
  CURLRESULT=$(curl -X GET -s -u "${BB_USER}:${BB_APP_PASSWORD}" -H 'Content-Type: application/json' ${URL}\\{${UUID}\\})
  STATE=$(echo ${CURLRESULT} | jq --raw-output '.state.name')
  
  echo " ### Pipeline is in state ${STATE} ###"

  if [[ ${STATE} == "COMPLETED" ]]
  then
    CONTINUE=0
  fi
done

RESULT=$(echo ${CURLRESULT} | jq --raw-output '.state.result.name')
echo " ### Pipeline result is ${RESULT} ###"
[[ ${RESULT} == "SUCCESSFUL" ]] && exit 0
exit 1
