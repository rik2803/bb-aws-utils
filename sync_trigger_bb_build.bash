#! /bin/bash

echo "### Starting $(basename "${0}") ###"
### Install jq
scriptdir=$(dirname "${0}")
source ${scriptdir}/lib.bash

install_jq

### jq is required
if ! which jq >/dev/null 2>&1
then
  echo "### jq is required ###"
  exit 1
else
  echo "### jq is installed ###"
fi
 
[[ -z ${REMOTE_REPO_SLUG} ]] && { echo "REMOTE_REPO_SLUG is required"; exit 1; }
[[ -z ${BB_USER} ]]          && { echo "BB_USER is required"; exit 1; }
[[ -z ${BB_APP_PASSWORD} ]]  && { echo "BB_APP_PASSWORD is required"; exit 1; }

REPO_OWNER=${REMOTE_REPO_OWNER:=BITBUCKET_REPO_OWNER}
REPO_SLUG=${REMOTE_REPO_SLUG:=THIS_ONE_IS_REQUIRED}

export URL="https://api.bitbucket.org/2.0/repositories/${REPO_OWNER}/${REPO_SLUG}/pipelines/"

echo "### REPO_OWNER: ${REPO_OWNER} ###"
echo "### REPO_SLUG:  ${REPO_SLUG} ###"
echo "### URL:        ${URL} ###"

CURLRESULT=$(curl -X POST -s -u "${BB_USER}:${BB_APP_PASSWORD}" -H 'Content-Type: application/json' \
                  ${URL} -d '{ "target": { "ref_type": "branch", "type": "pipeline_ref_target", "ref_name": "master" } }')

UUID=$(echo "${CURLRESULT}" | jq --raw-output '.uuid' | tr -d '\{\}')

echo "UUID is ${UUID}"

if 

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
