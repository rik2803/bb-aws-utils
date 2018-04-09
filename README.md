# `bb-docker-aws-utils` - Bash functions to build and deploy docker images from a BitBucket pipeline

## Pipeline requirements

### Environment for docker image build and push

* `AWS_ACCESS_KEY_ID_ECR_SOURCE`
* `AWS_SECRET_ACCESS_KEY_ECR_SOURCE`
* `AWS_REGION_SOURCE`: Optional, default is `eu-central-1`
* `AWS_ACCESS_KEY_ID_ECR_TARGET`
* `AWS_SECRET_ACCESS_KEY_ECR_TARGET`
* `AWS_REGION_TARGET`: Optional, default is `eu-central-1`
* `DOCKER_IMAGE`

### Environment for triggering other pipeline

IMPORTANT: The script `sync_trigger_bb_build.bash` requires `jq`

* `BB_USER`
* `BB_APP_PASSWORD`: https://confluence.atlassian.com/bitbucket/app-passwords-828781300.html
* `REMOTE_REPO_OWNER`
* `REMOTE_REPO_SLUG`
