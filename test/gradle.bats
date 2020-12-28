#!/usr/bin/env bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
  # executed before each test
  echo "setup" >&3
  export GRADLE_PROPERTIES_PATH="."
  source "${LIB_DIR}/common.bash"
  source "${LIB_DIR}/gradle.bash"
}

teardown() {
  # executed after each test
  echo "teardown" >&3
  #echo $output >&3
  #rm -f ./gradle.properties || true
  true
}

@test "gradle_pass" {
  run gradle_pass
  assert_success
}

@test "gradle_create_gradle_properties" {
  export GRADLE_PROPERTY_KEYS="u1 u2 u3 u4"
  export GRADLE_PROPERTY_VALUES="p1 p2 p3"
  run gradle_create_gradle_properties
  source ./gradle.properties || true
  assert_equal ${u1} "p1"
  assert_equal ${u2} "p2"
  assert_equal ${u4} "NA"
}