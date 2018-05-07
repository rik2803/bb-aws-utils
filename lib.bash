install_awscli() {
  apt-get update
  apt-get install -y python-dev
  curl -O https://bootstrap.pypa.io/get-pip.py
  python get-pip.py
  pip install awscli
}

install_jq() {
  apt-get update
  apt-get install -y jq
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

docker_build_deploy_image() {
  echo "### Create Dockerfile ###"
  echo "FROM ${AWS_ACCOUNTID_SRC}.dkr.ecr.${AWS_REGION_SOURCE:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}:latest" > Dockerfile
  echo "### Start build of docker image ${DOCKER_IMAGE}-${ENVIRONMENT:-dev} ###"
  docker build -t ${DOCKER_IMAGE}-${ENVIRONMENT:-dev} .
}

set_dest_ecr_credentials() {
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

docker_deploy_image() {
  echo "### Force update service ${ECS_SERVICE} on ECS cluster ${ECS_CLUSTER} in region ${AWS_REGION} ###"
  aws ecs update-service --cluster ${ECS_CLUSTER} --force-new-deployment --service ${ECS_SERVICE} --region ${AWS_REGION:-eu-central-1}
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
  echo "### Ccreate tarfile ${ARTIFACT_NAME}-${BITBUCKET_COMMIT}.tgz from all files in ${PAYLOAD_LOCATION:-dist} ###"
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
  echo "### Deploy the payload to s3://${S3_DEST_BUCKET}/${S3_PREFIX} with ACL ${AWS_ACCESS_CONTROL:-private} ###"
  aws s3 cp --acl ${AWS_ACCESS_CONTROL:-private} --recursive . s3://${S3_DEST_BUCKET}/${S3_PREFIX}
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

s3_artifact() {
  echo "### Run the build command (${BUILD_COMMAND:-No build command}) ###"
  [[ -n ${BUILD_COMMAND} ]] && eval ${BUILD_COMMAND}
  echo "### Set AWS credentials for artifact upload (AWS_ACCESS_KEY_ID_S3_TARGET and AWS_SECRET_ACCESS_KEY_S3_TARGET) ###"
  set_credentials "${AWS_ACCESS_KEY_ID_S3_TARGET}" "${AWS_SECRET_ACCESS_KEY_S3_TARGET}"
  s3_deploy_create_tar_and_upload_to_s3
}
