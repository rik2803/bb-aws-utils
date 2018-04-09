# `bb-docker-aws-utils` - Bash functions to build and deploy docker images from a BitBucket pipeline

## Pipeline requirements

### Environment

* `AWS_ACCESS_KEY_ID_ECR_SOURCE`
* `AWS_SECRET_ACCESS_KEY_ECR_SOURCE`
* `AWS_REGION_SOURCE`: Optional, default is `eu-central-1`
* `AWS_ACCESS_KEY_ID_ECR_TARGET`
* `AWS_SECRET_ACCESS_KEY_ECR_TARGET`
* `AWS_REGION_TARGET`: Optional, default is `eu-central-1`
* `DOCKER_IMAGE`
