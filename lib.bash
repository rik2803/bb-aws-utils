run_log_and_exit_on_failure() {
  echo "### Starting ${1}"
  if ${1} 
  then
    echo "### ${1} successfully executed"
  else
    echo "### ERROR: ${1} failed, exiting ..."
    exit 1
  fi
}

install_awscli() {
  run_log_and_exit_on_failure "apt-get update"
  run_log_and_exit_on_failure "apt-get install -y python-dev"
  run_log_and_exit_on_failure "curl -O https://bootstrap.pypa.io/get-pip.py"
  run_log_and_exit_on_failure "python get-pip.py"
  run_log_and_exit_on_failure "pip install awscli"
}

install_maven2() {
  echo "### Start maven2 installation ###"
  run_log_and_exit_on_failure "apt-get update"
  run_log_and_exit_on_failure "apt-get install -y maven2"
}

install_jq() {
  echo "### Start jq installation ###"
  run_log_and_exit_on_failure "apt-get update"
  run_log_and_exit_on_failure "apt-get install -y jq"

  ### jq is required
  if ! which jq >/dev/null 2>&1
  then
    echo "### jq is required ###"
    exit 1
  else
    echo "### jq is installed ###"
  fi
}

repo_git_url() {
  echo "git@bitbucket.org:${REMOTE_REPO_OWNER}/${REMOTE_REPO_SLUG}.git"
}

create_TAG_file_in_remote_url() {
  # To make sure the deploy pipeline uses the correct docker image tag,
  # this functions:
  #   - clones the remote repo
  #   - creates or updates a file named TAG in the root of the repo
  #   - the TAG file contains the commit hash of the SW git repo commit
  #   - adds, commits ans pushes the changes
  # The pipeline of the config repo will then use the content of the file
  # to determine the tag of the docker image to pull and use to create
  # the deploy image.
  #
  # This requires that pipeline to have a SSH key:
  #   bb -> repo -> settings -> pipelines -> SSH keys
  #
  # That ssh key should be granted read/write permissions to the repo
  # to be cloned, changed, committed and pushed, and will be available
  # as ~/.ssh/id_rsa 

  ### It's useless to do this if no SSHKEY is configured in the pipeline.
  if [[ ! -e /opt/atlassian/pipelines/agent/data/id_rsa ]]  
  then
    echo "### ERROR: No SSH Key is configured in the pipeline, and this is required ###"
    echo "###        to be able to add/update the TAG file in the remote (config)   ###"
    echo "###        repository.                                                    ###"
    echo "###        Add a key to the repository and try again.                     ###"
    echo "###            bb -> repo -> settings -> pipelines -> SSH keys            ###"
    exit 1
  fi
 
  ### Construct remote repo HTTPS URL
  REMOTE_REPO_URL=$(repo_git_url)

  echo "### Remote repo URL is ${REMOTE_REPO_URL} ###"
  
  ### git config
  git config --global user.email "bitbucketpipeline@ixor.be"
  git config --global user.name "Bitbucket Pipeline"
  
  echo "### Trying to clone ${REMOTE_REPO_URL} into remote_repo ###"
  rm -rf remote_repo
  git clone ${REMOTE_REPO_URL} remote_repo || { echo "### Error cloning ${REMOTE_REPO_URL} ###"; exit 1; }
  echo "### Update the TAG file in the repo ###"
  echo "${BITBUCKET_COMMIT}" > remote_repo/TAG
  cd remote_repo
  git add TAG
  ### If 2 pipelines run on same commit, the TAG file will not change
  if ! git diff-index --quiet HEAD --
  then
    echo "### TAG file was updated, committing and pushing the change ###"
    git commit -m 'Update TAG with source repo commit hash' || { echo "### Error committing TAG ###"; exit 1; }
    git push || { echo "### Error pushing to ${REMOTE_REPO_URL} ###"; exit 1; }
  else
    echo "### TAG file was unchanged, because the pipeline for this commit has been run before. ###"
    echo "### No further (git) actions required.                                                ###"
  fi

  REMOTE_REPO_COMMIT_HASH=$(git rev-parse HEAD)
  echo "### Full commit hash of remote repo is ${REMOTE_REPO_COMMIT_HASH} ###"
  cd -
}

start_pipeline_for_remote_repo() {
  REMOTE_REPO_COMMIT_HASH=${1}

  export URL="https://api.bitbucket.org/2.0/repositories/${REMOTE_REPO_OWNER}/${REMOTE_REPO_SLUG}/pipelines/"
  
  echo "### REMOTE_REPO_OWNER:       ${REMOTE_REPO_OWNER} ###"
  echo "### REMOTE_REPO_SLUG:        ${REMOTE_REPO_SLUG} ###"
  echo "### URL:                     ${URL} ###"
  echo "### REMOTE_REPO_COMMIT_HASH: ${REMOTE_REPO_COMMIT_HASH} ###"
  
  cat > /curldata << EOF
{
  "target": {
    "commit": {
      "hash":"${REMOTE_REPO_COMMIT_HASH}",
      "type":"commit"
    },
    "selector": {
      "type":"custom",
      "pattern":"build_and_deploy"
    },
    "type":"pipeline_commit_target"
  }
}
EOF
  CURLRESULT=$(curl -X POST -s -u "${BB_USER}:${BB_APP_PASSWORD}" -H 'Content-Type: application/json' \
                    ${URL} -d '@/curldata')
  
  UUID=$(echo "${CURLRESULT}" | jq --raw-output '.uuid' | tr -d '\{\}')
  BUILDNUMBER=$(echo "${CURLRESULT}" | jq --raw-output '.build_number')
  
  if [[ ${UUID} = "null" ]]
  then
    echo "### ERROR: An error occured when triggering the pipeline ###"
    echo "###        for ${REMOTE_REPO_SLUG} ###"
    echo "### Curl data and return object follow ###"
    cat /curldata
    echo "###"
    echo "${CURLRESULT}" | jq .
    exit 1
  fi

  echo "### Remote pipeline is started and has UUID is ${UUID} ###"
  echo "### Link to the remote pipeline result is: ###"
  echo "###   https://bitbucket.org/${REMOTE_REPO_OWNER}/${REMOTE_REPO_SLUG}/addon/pipelines/home#!/results/${BUILDNUMBER} ###"
  
  CONTINUE=1
  SLEEP=10
  STATE="NA"
  RESULT="na"
  CURLRESULT="NA"
  
  echo "### Monitoring remote pipeline with UUID ${UUID} with interval ${SLEEP} ###"
  while [[ ${CONTINUE} = 1 ]]
  do
    sleep ${SLEEP}
    CURLRESULT=$(curl -X GET -s -u "${BB_USER}:${BB_APP_PASSWORD}" -H 'Content-Type: application/json' ${URL}\\{${UUID}\\})
    STATE=$(echo ${CURLRESULT} | jq --raw-output '.state.name')
  
    echo "  ### Pipeline is in state ${STATE} ###"
  
    if [[ ${STATE} == "COMPLETED" ]]
    then
      CONTINUE=0
    fi
  done
  
  RESULT=$(echo ${CURLRESULT} | jq --raw-output '.state.result.name')
  echo "### Pipeline result is ${RESULT} ###"

  RETURNVALUE="${RESULT}"
}

set_credentials() {
  access_key=${1}
  secret_key=${2}
  echo "### Setting environment for AWS authentication ###"
  AWS_ACCESS_KEY_ID="${access_key}"
  AWS_SECRET_ACCESS_KEY="${secret_key}"
  export AWS_ACCESS_KEY_ID
  export AWS_SECRET_ACCESS_KEY
}

set_source_ecr_credentials() {
  set_credentials "${AWS_ACCESS_KEY_ID_ECR_SOURCE}" "${AWS_SECRET_ACCESS_KEY_ECR_SOURCE}"
  echo "### Logging in to AWS ECR source ###"
  eval $(aws ecr get-login --no-include-email --region ${AWS_REGION_SOURCE:-eu-central-1})
}

docker_build() {
  install_awscli
  eval $(aws ecr get-login --no-include-email --region ${AWS_REGION_SOURCE:-eu-central-1})
  ### The Dockerfile is supposed to be in a subdir docker of the repo
  cd /${BITBUCKET_CLONE_DIR}/docker

  echo "### Start build of docker image ${DOCKER_IMAGE} ###"
  docker build -t ${DOCKER_IMAGE} .
  echo "### Tagging docker image ${DOCKER_IMAGE}:${BITBUCKET_COMMIT} ###"
  docker tag ${DOCKER_IMAGE} ${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}
  docker tag ${DOCKER_IMAGE} ${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}:${BITBUCKET_COMMIT}
  echo "### Pushing docker image ${DOCKER_IMAGE}:${BITBUCKET_COMMIT} to ECR ###"
  docker push ${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}
  docker push ${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}:${BITBUCKET_COMMIT}
}

docker_build_application_image() {
  echo "### Docker info ###"
  docker info
  echo "### Start build of docker image ${DOCKER_IMAGE} ###"
  docker build -t ${DOCKER_IMAGE} .
}

docker_build_deploy_image() {
  echo "### Determine the TAG to use for the docker pull from the file named TAG ###"
  export TAG="latest"
  [[ -e TAG ]] && TAG=$(cat TAG)

  echo "### Create Dockerfile ###"
  echo "FROM ${AWS_ACCOUNTID_SRC}.dkr.ecr.${AWS_REGION_SOURCE:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}:${TAG:-latest}" > Dockerfile
  echo "### Start build of docker image ${DOCKER_IMAGE}-${ENVIRONMENT:-dev} based on the artefact image with tar ${TAG:-latest} ###"
  docker build --build-arg="BITBUCKET_COMMIT=${BITBUCKET_COMMIT:-NA}" -t ${DOCKER_IMAGE}-${ENVIRONMENT:-dev} .
}

set_dest_ecr_credentials() {
  echo "### Fallback to AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY if AWS_ACCESS_KEY_ID_ECR_TARGET or AWS_SECRET_ACCESS_KEY_ECR_TARGET are not defined"
  [[ -z ${AWS_ACCESS_KEY_ID_ECR_TARGET} ]] && [[ -n ${AWS_ACCESS_KEY_ID} ]] && AWS_ACCESS_KEY_ID_ECR_TARGET=${AWS_ACCESS_KEY_ID}
  [[ -z ${AWS_SECRET_ACCESS_KEY_ECR_TARGET} ]] && [[ -n ${AWS_SECRET_ACCESS_KEY} ]] && AWS_SECRET_ACCESS_KEY_ECR_TARGET=${AWS_SECRET_ACCESS_KEY}
  set_credentials "${AWS_ACCESS_KEY_ID_ECR_TARGET}" "${AWS_SECRET_ACCESS_KEY_ECR_TARGET}"
  echo "### Logging in to AWS ECR target ###"
  eval $(aws ecr get-login --no-include-email --region ${AWS_REGION_TARGET:-eu-central-1})
}

docker_tag_and_push_deploy_image() {
  echo "### Tagging docker image ${DOCKER_IMAGE}-${ENVIRONMENT:-dev} ###"
  docker tag ${DOCKER_IMAGE}-${ENVIRONMENT:-dev} ${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}-${ENVIRONMENT:-dev}
  echo "### Pushing docker image ${DOCKER_IMAGE}-${ENVIRONMENT:-dev} to ECR ###"
  docker push ${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}-${ENVIRONMENT:-dev}
}

docker_tag_and_push_application_image() {
  echo "### Tagging docker image ${DOCKER_IMAGE} ###"
  docker tag ${DOCKER_IMAGE} ${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}
  docker tag ${DOCKER_IMAGE} ${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}:${BITBUCKET_COMMIT}
  echo "### Pushing docker image ${DOCKER_IMAGE} to ECR ###"
  docker push ${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}
  docker push ${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}:${BITBUCKET_COMMIT}
}

docker_deploy_image() {
  if [[ -n ${CW_ALARM_SUBSTR} ]]
  then
    echo "### Disable all CloudWatch alarm actions to avoid panic reactions ###"
    CW_ALARMS=$(aws cloudwatch describe-alarms --region ${AWS_REGION:-eu-central-1} --query "MetricAlarms[*]|[?contains(AlarmName, '${CW_ALARM_SUBSTR}')].AlarmName" --output text)
    aws cloudwatch disable-alarm-actions --region ${AWS_REGION:-eu-central-1} --alarm-names ${CW_ALARMS:-NoneFound}
  fi

  echo "### Force update service ${ECS_SERVICE} on ECS cluster ${ECS_CLUSTER} in region ${AWS_REGION} ###"
  aws ecs update-service --cluster ${ECS_CLUSTER} --force-new-deployment --service ${ECS_SERVICE} --region ${AWS_REGION:-eu-central-1}

  if [[ -n ${CW_ALARM_SUBSTR} ]]
  then
    echo "### Allow the service to stabilize before re-enabling alarms (120 seconds)  ###"
    sleep 30
    echo "###    90 seconds remaining  ###"
    sleep 30
    echo "###    60 seconds remaining  ###"
    sleep 30
    echo "###    30 seconds remaining  ###"
    sleep 30
    echo "### Enable all CloudWatch alarm actions to guarantee the services being monitored ###"
    aws cloudwatch enable-alarm-actions --region ${AWS_REGION:-eu-central-1} --alarm-names ${CW_ALARMS:-NoneFound}
  fi
}

s3_deploy_apply_config_to_tree() {
  # In all files under ${basedir}, replace all occurences of __VARNAME__ to the value of
  # the environment variable CFG_VARNAME, for all envvars starting with CFG_
  basedir=${1}

  for VARNAME in ${!CFG_*}
  do
    SUBST_SRC="__${VARNAME##CFG_}__"
    SUBST_VAL=$(eval echo \$${VARNAME})
    echo "### Replacing all occurences of ${SUBST_SRC} to ${SUBST_VAL} in all files under ${basedir} ###"
    find ${basedir} -type f | xargs sed -i "" "s|${SUBST_SRC}|${SUBST_VAL}|g"
  done
}

s3_deploy_create_tar_and_upload_to_s3() {
  echo "### Create tarfile ${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz from all files in ${PAYLOAD_LOCATION:-dist} ###"
  tar -C ${PAYLOAD_LOCATION:-dist} -czvf ${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz .
  echo "### Copy ${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz to S3 bucket ${S3_ARTIFACT_BUCKET}/${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz ###"
  aws s3 cp ${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz s3://${S3_ARTIFACT_BUCKET}/${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz
  echo "### Copy ${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz to S3 bucket ${S3_ARTIFACT_BUCKET}/${ARTIFACT_NAME}-last.tgz ###"
  aws s3 cp ${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz s3://${S3_ARTIFACT_BUCKET}/${ARTIFACT_NAME}-last.tgz
}

s3_deploy_download_tar_and_prepare_for_deploy() {
  echo "### Download artifact ${ARTIFACT_NAME}-last.tgz from s3://${S3_ARTIFACT_BUCKET} ###"
  aws s3 cp s3://${S3_ARTIFACT_BUCKET}/${ARTIFACT_NAME}-last.tgz .
  echo "### Create workdir ###"
  mkdir -p workdir
  echo "### Untar the artifact file into the workdir ###"
  tar -C workdir -xzvf ${ARTIFACT_NAME}-last.tgz
  echo "### Start applying the config to the untarred files ###"
  s3_deploy_apply_config_to_tree workdir
}

s3_deploy_deploy() {
  cd workdir
  echo "### Deploy the payload to s3://${S3_DEST_BUCKET}/${S3_PREFIX:-} with ACL ${AWS_ACCESS_CONTROL:-private} ###"
  aws s3 cp --acl ${AWS_ACCESS_CONTROL:-private} --recursive . s3://${S3_DEST_BUCKET}/${S3_PREFIX:-}
  cd -
}

s3_deploy() {
  echo "### Set AWS credentials for artifact download (AWS_ACCESS_KEY_ID_S3_SOURCE and AWS_SECRET_ACCESS_KEY_S3_SOURCE) ###"
  set_credentials "${AWS_ACCESS_KEY_ID_S3_SOURCE}" "${AWS_SECRET_ACCESS_KEY_S3_SOURCE}"
  s3_deploy_download_tar_and_prepare_for_deploy
  echo "### Set AWS credentials for deploy (AWS_ACCESS_KEY_ID_S3_TARGET and AWS_SECRET_ACCESS_KEY_S3_TARGET) ###"
  set_credentials "${AWS_ACCESS_KEY_ID_S3_TARGET}" "${AWS_SECRET_ACCESS_KEY_S3_TARGET}"
  echo "### Start the deploy ###"
  s3_deploy_deploy
}

s3_lambda_build_and_push() {
  export CI=false
  install_awscli
  run_log_and_exit_on_failure "apt-get install -y zip"
  run_log_and_exit_on_failure "mkdir /builddir"

  ### Node
  if [[ ${LAMBDA_RUNTIME} = nodejs* ]]
  then
    run_log_and_exit_on_failure "mv ${LAMBDA_FUNCTION_FILE:-index.js} /builddir"
    if [[ -f package.json ]]
    then
      run_log_and_exit_on_failure "npm install"
      run_log_and_exit_on_failure "mv node_modules /builddir"
    fi
  fi

  ### Python
  if [[ ${LAMBDA_RUNTIME} = python* ]]
  then
    run_log_and_exit_on_failure "mv ${LAMBDA_FUNCTION_FILE:-lambda.py} /builddir"
    if [[ -f requirements.txt ]]
    then
      run_log_and_exit_on_failure "pip install -r requirements.txt --target /builddir"
    fi
  fi

  echo "### Zip the Lambda code and dependencies"
  run_log_and_exit_on_failure "cd /builddir"
  run_log_and_exit_on_failure "zip -r /${LAMBDA_FUNCTION_NAME}.zip *"

  echo "### Push the zipped file to S3 bucket ${S3_DEST_BUCKET}"
  set_credentials "${AWS_ACCESS_KEY_ID}" "${AWS_SECRET_ACCESS_KEY}"
  run_log_and_exit_on_failure "aws s3 cp --acl private /${LAMBDA_FUNCTION_NAME}.zip s3://${S3_DEST_BUCKET}/${LAMBDA_FUNCTION_NAME}.zip"
  run_log_and_exit_on_failure "aws s3 cp --acl private /${LAMBDA_FUNCTION_NAME}.zip s3://${S3_DEST_BUCKET}/${LAMBDA_FUNCTION_NAME}-${BITBUCKET_COMMIT}.zip"
}

s3_artifact() {
  install_awscli
  echo "### Run the build command (${BUILD_COMMAND:-No build command}) ###"
  create_npmrc
  [[ -n ${BUILD_COMMAND} ]] && eval ${BUILD_COMMAND}
  echo "### Set AWS credentials for artifact upload (AWS_ACCESS_KEY_ID_S3_TARGET and AWS_SECRET_ACCESS_KEY_S3_TARGET) ###"
  set_credentials "${AWS_ACCESS_KEY_ID_S3_TARGET}" "${AWS_SECRET_ACCESS_KEY_S3_TARGET}"
  s3_deploy_create_tar_and_upload_to_s3
}

create_npmrc() {
  echo "### Create ~/.npmrc file for NPMJS authentication ###"
  echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN:-NA}" > ~/.npmrc
}
