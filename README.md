# `bb-aws-utils` - Bash functions to build and deploy docker images from a BitBucket pipeline

## What these functions can be used for

* Build Java project, build a docker container and push the container to a AWS ECR repo
* Build an (NPM) project, create a tarball and push it to a S3 bucket
* Package a Lambda function, ZIP it and push it to a S3 bucket

## Pipeline requirements

The environment can be defined in 2 places:

* The BB pipeline settings (this is the preferred way for secrets)
* With a `export` statement in the `bitbucket-pipel;ines.yml` file. This
  should **not be used** for secrets

### Environment for docker image build and push

* `AWS_ACCESS_KEY_ID_ECR_SOURCE`
* `AWS_SECRET_ACCESS_KEY_ECR_SOURCE`
* `AWS_REGION_SOURCE`: Optional, default is `eu-central-1`
* `AWS_ACCESS_KEY_ID_ECR_TARGET`
* `AWS_SECRET_ACCESS_KEY_ECR_TARGET`: **Must be seccret**
* `AWS_REGION_TARGET`: Optional, default is `eu-central-1`
* `DOCKER_IMAGE`

### Environment for triggering pipeline for another project

The `deploy` step triggers the pipeline of a repository that contains the configuration
for that specific environment. This trigger is done using the BB pipeline REST API.

IMPORTANT: The script `sync_trigger_bb_build.bash` requires `jq`

* `BB_USER`
* `BB_APP_PASSWORD`: See [here](https://confluence.atlassian.com/bitbucket/app-passwords-828781300.html) to create a BB application password
* `REMOTE_REPO_OWNER`
* `REMOTE_REPO_SLUG`

## Build a docker deploy image and deploy to AWS ECS Cluster Service

What this does:

* First pipeline step:
  * use the credentials `AWS_ACCESS_KEY_ID_ECR_SOURCE` and
    `AWS_SECRET_ACCESS_KEY_ECR_SOURCE` to login to the source ECR
  * build a new docker image _FROM_ the image
    `${AWS_ACCOUNTID_SRC}.dkr.ecr.${AWS_REGION_SOURCE:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}:${TAG:-latest}`
    where `${TAG}` is the content of the file `TAG`
  * use the credentials `AWS_ACCESS_KEY_ID_ECR_TARGET` and
    `AWS_SECRET_ACCESS_KEY_ECR_TARGET` to login to the target ECR
  * Tag the new image and push it to `${AWS_ACCOUNTID_TARGET}.dkr.ecr.${AWS_REGION_TARGET:-eu-central-1}.amazonaws.com/${DOCKER_IMAGE}-${ENVIRONMENT:-dev}`
* Second pipeline step
  * Disable the alarms that contain the string in the variable `${CW_ALARM_SUBSTR}`
    (skip this step if the variable is not set)
  * Run following command to forcibly update (this will pull the latest image from the task's definition) of the
    service:

```
aws ecs update-service --cluster ${ECS_CLUSTER} --force-new-deployment --service ${ECS_SERVICE} --region ${AWS_REGION:-eu-central-1}
``` 

  * And finally wait 120 seconds for the update to finish and enable the _CloudWatch_ alarms (skip this step if the variable  `CW_ALARM_SUBSTR` is not set)

### Example BB pipeline file

```yaml
image: python:3.6

pipelines:
  custom:
    build_and_deploy:
      - step:
          name: Build and push Docker deploy image
          script:
            - git clone https://github.com/rik2803/bb-aws-utils.git
            - export AWS_REGION=eu-central-1
            - export AWS_ACCOUNTID_SRC=123456789012
            - export AWS_ACCOUNTID_TARGET=210987654321
            - export ECS_CLUSTER=my-ecs-cluster
            - export ECS_SERVICE=my-service
            - export ENVIRONMENT=dev
            - export DOCKER_IMAGE=my/service-image
            - bb-aws-utils/build-and-push-docker-image.bash
      - step:
          name: Deploy latest version of image
          script:
            - git clone https://github.com/rik2803/bb-aws-utils.git
            - export AWS_REGION=eu-central-1
            - export ECS_CLUSTER=my-ecs-cluster
            - export ECS_SERVICE=my-service
            - export ENVIRONMENT=dev
            - export DOCKER_IMAGE=my/service-image
            - export CW_ALARM_SUBSTR=MyServiceAlarm
            - bb-aws-utils/deploy-docker-image.bash
options:
  docker: true
```

### Environment
* `AWS_ACCESS_KEY_ID_ECR_SOURCE` and `AWS_SECRET_ACCESS_KEY_ECR_SOURCE`: Credentials for the
  source ECR where the docker image is based upon.
* `AWS_ACCOUNTID_SRC`: AccountID where the source ECR is hosted
* `AWS_ACCESS_KEY_ID_ECR_TARGET` and `AWS_SECRET_ACCESS_KEY_ECR_TARGET`: Credentials for the
  destinatino ECR in the account of the environment where the service is running
* `AWS_ACCOUNTID_TARGET`: AccountID where the destination ECR is hosted
* `AWS_REGION`: The region (optional, default is `eu-central-1`)
* `ECS_CLUSTER`: The name of the cluster where the service to update is running
* `ECS_SERVICE`: The name of the service to update
* `ENVIRONMENT`: The environment (`dev`, `prd`, ...)
* `DOCKER_IMAGE`: The name of the docker image, without the tag
* `CW_ALARM_SUBSTR`: Determines the _CloudWatch_ alarms that will be paused during
  deployment of the service

## Package a Lambda function

### How

This explains how to build the Lambda function package and publish it to an S3 bucket.
Whenever the function is required in an AWS account, it can be downloaded from that bucket.

It's important that the accounts that need to use the Lambda function have read
access to the S3 bucket to be able to installthe Lambda function.

The BB pipeline build requires these pipeline environment variables:

* `LAMBDA_RUNTIME`: One of:
  * `python2.7`
  * `python3.6`
  * `nodejs8.10`
* `LAMBDA_FUNCTION_NAME`: The name to use to store the function in the S3 bucket
* `S3_DEST_BUCKET`: The name of the bucket the function should be deployed to
* `AWS_ACCESS_KEY_ID`: Credentials with write access to `S3_DEST_BUCKET`
* `AWS_SECRET_ACCESS_KEY`: Credentials with write access to `S3_DEST_BUCKET`

The result of a succeeded pipeline run is:

* A S3 object named `${LAMBDA_FUNCTION_NAME}.zip` on the bucket `S3_DEST_BUCKET`
* A S3 object named `${LAMBDA_FUNCTION_NAME}-${BITBUCKET_COMMIT}.zip` on the bucket `S3_DEST_BUCKET`

It is adviced to use the S3 object that has the commit string in its name, to have a form of version management.


#### `python` specific actions

* If libraries need to be installed, create a `requirements.txt` file in the root of your
  project. The dependencies will be installed by the pipeline.
* The Lambda function file should be called `lambda.py` or referenced by the
  environment variable `LAMBDA_FUNCTION_FILE`

#### `nodejs` specific actions

* If libraries need to be installed, create a `package.json` file in the root of your
  project. The dependencies will be installed with `npm i` by the pipeline if this
  file exists.
* The Lambda function file should be called `index.js` or referenced by the
  environment variable `LAMBDA_FUNCTION_FILE`

### A `bitbucket-pipelines.yml` example

#### For `python`

```

```


#### For `nodejs`

As mentioned earlier, the evnironment can be set in `bitbucket-pipelines.yml` or in the BB Pipeline settings. To easily set configure a repository for BB Pipelines, checkout [this GitHub repository](https://github.com/rik2803/bb-pipeline-setup).

```
image: node:8
pipelines:
  custom:
    build_lambda_function_package_and_publish_to_s3:
      - step:
          name: Build the lambda function package publish to S3
          caches:
            - node
          script:
            - git clone https://github.com/rik2803/bb-docker-aws-utils.git
            - source bb-docker-aws-utils/lib.bash
            - export S3_DEST_BUCKET=ixortooling-prd-s3-lambda-function-store
            - export LAMBDA_FUNCTION_NAME=sns-to-google-chat
            - s3_lambda_build_and_push
```


### Links and Resources

* [Create a Lambda Function Deployment Package](https://docs.aws.amazon.com/lambda/latest/dg/deployment-package-v2.html)
