#!/usr/bin/env bash

### Set credentials for tryx-sandbox
export AWS_PROFILE=tryx-sandbox

### VARS
REPOSITORIES="dockertest dockertest-tst dockertest-acc dockertest-prd"
### Create ECR Repositories

create_repositories() {
    for ecr in ${REPOSITORIES}
    do
        aws ecr create-repository --repository-name tryx/${ecr}
    done
}

remove_repositories() {
    for ecr in ${REPOSITORIES}
    do
        aws ecr deleete-repository --repository-name tryx/${ecr}
    done
}

create_repositories
