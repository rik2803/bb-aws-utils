# `bb-aws-utils`: A `bash` library for CI/CD

## Introduction

This library contains multiple modules that each cover a specific domain. These
modules are designed in a way that there is no dependency between the modules to
allow them to be used in as much as possible projects and environments.

## Best practices using the library

* Never put sensitive information in the pipeline configuration file. Usernames, passwords, hostnames
  and other pieces of information that might be abused should be defined as a (secret) property of
  the repository (i.e. _Repository variables_ in _BitBucket_)
* The AWS credentials should have exactly the permissions for the task they are used for
* Better create a separate user for each AWS task

## Let's start with an example

The example features a project written in Java, build using `maven` and deployed to
AWS ECS, and the code live in a _BitBucket_ repository, and the CI/CD is performed
by _BitBucket Pipelines_.

The `bitbucket-pipelines.yml` file that performs a snapshot build on a commit on `develop`, and
a deploy to a AWS ECS `tst` environment looks like this:

```yaml
pipelines:
  branches:
    develop:
      - step:
          name: Snapshot build
          image: atlassian/default-image:2
          caches:
            - maven
          script:
            - git clone -b ${BB_AWS_UTILS_VERSION} https://github.com/rik2803/bb-aws-utils.git
            - export LIB_DIR="./bb-aws-utils/lib"
            - source bb-aws-utils/lib/load.bash
            - maven_build
          artifacts:
            - artifacts/**
      - step:
          name: Deploy snapshot build to tst
          image: atlassian/pipelines-awscli:latest
          script:
            - git clone -b ${BB_AWS_UTILS_VERSION} https://github.com/rik2803/bb-aws-utils.git
            - export LIB_DIR="./bb-aws-utils/lib"
            - source bb-aws-utils/lib/load.bash
            - export AWS_ACCESS_KEY_ID=${AWS_ECS_ACCESS_KEY_ID_TST}
            - export AWS_SECRET_ACCESS_KEY="${AWS_ECS_SECRET_ACCESS_KEY_TST}"
            - echo "The next command sets the envvar MAVEN_CURRENT_VERSION"
            - maven_get_current_version
            - >
              aws_update_service ${AWS_ECS_CLUSTER_NAME_TST} ${AWS_ECS_SERVICE_NAME}
              ${AWS_ECS_TASK_FAMILY} ${MAVEN_CURRENT_VERSION} tryxcom/${AWS_ECS_TASK_FAMILY}

options:
  docker: true
```

To load the library, following three lines are always required:

```yaml
            - git clone -b ${BB_AWS_UTILS_VERSION} https://github.com/rik2803/bb-aws-utils.git
            - export LIB_DIR="./bb-aws-utils/lib"
            - source bb-aws-utils/lib/load.bash
```

The environment variable `${BB_AWS_UTILS_VERSION}` specifies the version of the library to use. Check
the `RELEASES.md` file for available versions and the changes. If not specified (i.e. if the command is
`git clone https://github.com/rik2803/bb-aws-utils.git`), the `master` branch will be used.

To perform a _Maven_ build, two functions are available:

* `maven_build`
* `maven_release_build`

## The `maven` module

### Overview of environment variables used in the `maven` module

| Variable name             | Req?| Description                                    | Default                           |
|---------------------------|-----|------------------------------------------------|-----------------------------------|
| `MAVEN_SETTINGS_ID`       | no  | Used to create `settings.xml` file             |                                   |
| `MAVEN_SETTINGS_USERNAME` | no  | Used to create `settings.xml` file             |                                   |
| `MAVEN_SETTINGS_PASSWORD` | no  | Used to create `settings.xml` file             |                                   |
| `MAVEN_SETTINGS_EMAIL`    | no  | Used to create `settings.xml` file             |                                   |
| `MAVEN_SETTINGS_PATH`     | no  | Path where `settings.xml` should be            | `/`                               |
| `MAVEN_MINOR_BUMP_STRING` | no  | String to determine if minor version is bumped | `bump_minor_version`              |
| `MAVEN_DEVELOP_COMMAND`   | no  | Maven phases to run for snapshot build         | `clean deploy`                    |
| `MAVEN_RELEASE_COMMAND`   | no  | Maven phases to run for release build          | `release:prepare release:perform` |
| `MAVEN_EXTRA_ARGS`        | no  | Extra arguments to pass to the `mvn` command   |                                   |

### Generate the `settings.xml` file

The `settings.xml` file should never be part of the repository for the same reason you don't put
usernames and passwords in a _POM_ file. Therefor, the file should be generated, getting the
required information from the environment, set by the repository hosting company from settings
you enter. Always remember to make passwords and other sensitive information _Secret_ so the
values are not accessible or logged in the build or deploy log.

The `settings.xml` file is generated from these 3 environment variables:

* `MAVEN_SETTINGS_ID`: Space separated string af _Id_'s
* `MAVEN_SETTINGS_USERNAME`: Space separated string of usernames
* `MAVEN_SETTINGS_PASSWORD`: Space separated string of passwords (**SECRET!!!**)
* `MAVEN_SETTINGS_EMAIL`: Space separated string of e-mail addresses

The number of elements in each of these variables should be identical. If the e-mail address for
a _server_ is not required, use the value `NA` to keep the elements aligned.

### Perform a snapshot build

The function `maven_build` performs a snapshot build. The default phases are `clean deploy`, but
can be overridden by setting the environment variable `MAVEN_DEVELOP_COMMAND`.

At the end of the function, if everything was successful, a script `artifacts/MAVEN_CURRENT_VERSION`
is created for use in the next steps (a deploy step, for example).

### Perform a release build

The function `maven_release_build` performs a release build. The default phases are
`release:prepare release:perform`, but can be overridden by setting the environment variable
`MAVEN_RELEASE_COMMAND`.

At the end of the function, if everything was successful, a script `artifacts/MAVEN_CURRENT_VERSION`
is created for use in the next steps (a deploy step, for example).

The version of the release and the version of the next snapshot is determined like this:

* The current version is `M.m.p-SNAPSHOT`
* The last commit message contains the string defined in the environment variable
  `MAVEN_MINOR_BUMP_STRING` (default value is `bump_minor_version`)
  * The release version becomes `M.m+1.0`
  * The new snapshot version becomes `M.m+1.1-SNAPSHOT`
* The last commit message **does not** contain the bump string
  * The release version becomes `M.m.p`
  * The new snapshot version becomes `M.m.p+1-SNAPSHOT`

### Get the current version

The function `maven_get_current_version` sets the environment variable `MAVEN_CURRENT_VERSION`. That
variable van be used to pass to steps that require the version string.

## The `aws` module

### Overview of environment variables used in the `maven` module

| Variable name           | Req?| Description     | Default                 |
|-------------------------|-----|-----------------|-------------------------|
| `AWS_DEFAULT_REGION`    | no  | AWS Region      | `eu-west-1` (Frankfurt) |
| `AWS_ACCESS_KEY_ID`     | yes | AWS Credentials |                         |
| `AWS_SECRET_ACCESS_KEY` | yes | AWS Credentials |                         |

The user whose AWS Credentials are used, should have enough (but not too much)
rights to perform the AWS related tasks for which the credentials are used.

### Update an ECS service

The function `aws_update_service` can be used to update an existing AWS ECS service with
the Docker artifact that is available in a Docker image repository.

The command needs a number of arguments:

| Argument name           | Description                                            | Example                    |
|-------------------------|--------------------------------------------------------|----------------------------|
| `aws_ecs_cluster_name ` | Name of the ECS cluster where the service is running   | `MyCluster`                |
| `aws_ecs_task_family `  | The ECS task family                                    | `example-service`          |
| `aws_ecs_service_name ` | The ECS service name                                   | `example-service`          |
| `image_tag `            | The Docker image tag to run                            | `0.0.7`                    |
| `image_basename `       | The Docker image basename (everything without the tag) | `ixortalk/example-service` |
