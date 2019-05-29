#!/usr/bin/env bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
  source "./lib/common.bash"
  source "./lib/aws.bash"
}

teardown() {
  true
}

@test "true" {
  run true
  assert_success
}
