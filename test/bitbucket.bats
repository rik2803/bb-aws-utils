#!/usr/bin/env bats

load "libs/bats-support/load"
load "libs/bats-assert/load"

setup() {
  # shellcheck source=../../bb-aws-utils/lib/bitbucket.bash
  source "${LIB_DIR}/bitbucket.bash"
  mkdir -p ./bats_rundir
  BITBUCKET_CLONE_DIR="./bats_rundir"
  BITBUCKET_COMMIT="251d8cada9c348f527fa5888298111539dd16e62"
}

teardown() {
  rm -rf ./bats_rundir
}

@test "true" {
  run true
  assert_success
}

@test "bb_is_config_repo_success_01" {
  BITBUCKET_REPO_SLUG="myproject.config.tst"
  touch "${BITBUCKET_CLONE_DIR}/TAG"
  run bb_is_config_repo
  assert_success "Test should return success!"
}

@test "bb_is_config_repo_failure_no_TAG_file" {
  BITBUCKET_REPO_SLUG="myproject.config.tst"
  run bb_is_config_repo
  assert_success "TAG does not exist the very first time!!"
}

@test "bb_is_config_repo_failure_no_config_repo" {
  BITBUCKET_REPO_SLUG="myproject"
  touch "${BITBUCKET_CLONE_DIR}/TAG"
  run bb_is_config_repo
  assert_failure "Test should fail!"
}