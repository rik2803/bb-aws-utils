#!/usr/bin/env bats

load "libs/bats-support/load"
load "libs/bats-assert/load"

setup() {
  # shellcheck source=../../bb-aws-utils/lib/common.bash
  source "${LIB_DIR}/common.bash"
}

@test "check_envvar required with mode" {
  export TESTVAR=testvarvalue
  run check_envvar TESTVAR R
  [ $status = 0 ] && [ ${TESTVAR} = testvarvalue ]
}

@test "check_envvar required without mode" {
  export TESTVAR=testvarvalue
  run check_envvar TESTVAR
  [ $status = 0 ] && [ ${TESTVAR} = testvarvalue ]
}

@test "check_envvar required not set with mode" {
  unset TESTVAR
  run check_envvar TESTVAR R
  [ $status = 1 ]
}

@test "check_envvar required var not set without mode" {
  unset TESTVAR
  run check_envvar TESTVAR
  [ $status = 1 ]
}

@test "check_envvar optional no default not set" {
  run check_envvar TESTVAR O
  [ $status = 0 ]
}

@test "check_envvar optional default set to empty string - 1" {
  run check_envvar TESTVAR O \"\"
  [ $status = 0 ]
}

@test "check_envvar optional default set to empty string - 2" {
  run check_envvar TESTVAR O \"\"
  [ $status = 0 ]
}

@test "check_envvar optional default set" {
  export TESTVAR=testvalue
  run check_envvar TESTVAR O default
  [ $status = 0 ]
  [ ${TESTVAR} = testvalue ]
}

@test "check_envvar optional default set 2 words" {
  export TESTVAR="testvalue testvalue"
  run check_envvar TESTVAR O default
  [ $status = 0 ]
  [ "${TESTVAR}" = "testvalue testvalue" ]
}

@test "check_envvar optional default not set" {
  run check_envvar TESTVAR O default
  [ $status = 0 ]
}

@test "check_command success" {
  run check_command ls
  [ $status = 0 ]
}

@test "check_command failure" {
  run check_command nonotme
  [ $status = 1 ]
}

@test "run_cmd success" {
  run run_cmd true
  [ $status = 0 ]
}

@test "run_cmd failure" {
  run run_cmd false
  # Allthough false failse, run_cmd returns 0
  [ $status = 0 ]
}

@test "get_parent_slug_from_repo_slug_01" {
  BITBUCKET_REPO_SLUG="myproject.config.prd"
  local project
  project=$(get_parent_slug_from_repo_slug)
  assert_equal "${project}" "myproject" "Expecting myproject as service for ${BITBUCKET_REPO_SLUG}"
}

@test "get_parent_slug_from_repo_slug_02" {
  BITBUCKET_REPO_SLUG="myproject.configuration.prd"
  local project
  project=$(get_parent_slug_from_repo_slug)
  assert_equal "${project}" "myproject.configuration.prd" "Expecting myproject.configuration.prd as service for ${BITBUCKET_REPO_SLUG}"
}

@test "get_parent_slug_from_repo_slug_03" {
  BITBUCKET_REPO_SLUG="myproject.config.prd"
  local env
  env=$(get_parent_slug_from_repo_slug)
  assert_equal "${env}" "myproject" "Expecting prd as environment for ${BITBUCKET_REPO_SLUG}"
}

@test "get_config_env_from_repo_slug_02" {
  BITBUCKET_REPO_SLUG="myproject.configuration.prd"
  local env
  env=$(get_config_env_from_repo_slug)
  assert_equal "${env}" "" "Expecting empty string as environment for ${BITBUCKET_REPO_SLUG}"
}

@test "get_config_env_from_repo_slug_03" {
  BITBUCKET_REPO_SLUG="myproject"
  local env
  env=$(get_config_env_from_repo_slug)
  assert_equal "${env}" "" "Expecting empty string as environment for ${BITBUCKET_REPO_SLUG}"
}

@test "global_var_PARENT_SLUG_01" {
  BITBUCKET_REPO_SLUG="myproject.config.stg"
  # shellcheck source=../../bb-aws-utils/lib/common.bash
  source "${LIB_DIR}/load.bash"
  assert_equal "${PARENT_SLUG}" "myproject"
}

@test "global_var_PARENT_SLUG_02" {
  BITBUCKET_REPO_SLUG="myproject"
  # shellcheck source=../../bb-aws-utils/lib/common.bash
  source "${LIB_DIR}/load.bash"
  assert_equal "${PARENT_SLUG}" "myproject"
}

@test "global_var_PARENT_SLUG_03" {
  unset BITBUCKET_REPO_SLUG
  # shellcheck source=../../bb-aws-utils/lib/common.bash
  source "${LIB_DIR}/load.bash"
  assert_equal "${PARENT_SLUG}" ""
}

@test "global_var_CONFIG_ENV_01" {
  BITBUCKET_REPO_SLUG="myproject.config.stg"
  # shellcheck source=../../bb-aws-utils/lib/common.bash
  source "${LIB_DIR}/load.bash"
  assert_equal "${CONFIG_ENV}" "stg"
}

@test "global_var_CONFIG_ENV_02" {
  BITBUCKET_REPO_SLUG="myproject"
  # shellcheck source=../../bb-aws-utils/lib/common.bash
  source "${LIB_DIR}/load.bash"
  assert_equal "${CONFIG_ENV}" ""
}

@test "global_var_CONFIG_ENV_03" {
  unset BITBUCKET_REPO_SLUG
  # shellcheck source=../../bb-aws-utils/lib/common.bash
  source "${LIB_DIR}/load.bash"
  assert_equal "${CONFIG_ENV}" ""
}
