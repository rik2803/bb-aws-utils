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

#### `python` specific actions

* If libraries need to be installed, create a `requirements.txt` file in the root of your
  project. The dependencies will be installed by the pipeline

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
