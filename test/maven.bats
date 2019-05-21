#!/usr/bin/env bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
  source "./lib/common.bash"
  source "./lib/maven.bash"
}

teardown() {
  rm -f ./settings.xml || true
  true
}

@test "maven_create_settings_xml" {
  export MAVEN_SETTINGS_ID="id1 id2 id3"
  export MAVEN_SETTINGS_USERNAME="u1 u2 u3"
  export MAVEN_SETTINGS_PASSWORD="p1 p2 p3"
  export MAVEN_SETTINGS_PATH="./"
  run maven_create_settings_xml
  lines=$(cat ${MAVEN_SETTINGS_PATH}/settings.xml | wc -l | tr -d ' ')
  assert_success
  assert_equal $lines 25
}

@test "maven_minor_bump true" {
  function git_current_commit_message() { echo "bump_minor_version"; }
  export -f git_current_commit_message
  run maven_minor_bump
  assert_success
  unset git_current_commit_message
}

@test "maven_set_versions 1.0.4" {
  function git_current_commit_message() { echo "bump_minor_version"; }
  function mvn() {
    echo "1 0 4 2 1 5"
  }
  export -f mvn git_current_commit_message
  run maven_set_versions
  assert_success
  unset mvn git_current_commit_message
}

@test "maven_get_develop_version 1.0.4 patch" {
  function maven_minor_bump() {
    return 1
  }
  function mvn() {
    echo "1 0 4 2 1 5"
  }
  export -f mvn maven_minor_bump
  run maven_get_develop_version
  echo $output > /tmp/rikske
  assert_output --partial "1.0.5-SNAPSHOT"
  unset mvn maven_minor_bump
}

@test "maven_get_release_version 1.0.4 patch" {
  function maven_minor_bump() {
    return 1
  }
  function mvn() {
    echo "1 0 4 2 1 5"
  }
  export -f mvn maven_minor_bump
  run maven_get_release_version
  assert_output --partial "1.0.4"
  unset mvn maven_minor_bump
}

@test "maven_get_develop_version 1.0.4 minor" {
  function maven_minor_bump() {
    return 0
  }
  function mvn() {
    echo "1 0 4 2 1 5"
  }
  export -f mvn maven_minor_bump
  run maven_get_develop_version
  assert_output --partial "1.1.1-SNAPSHOT"
  unset mvn maven_minor_bump
}

@test "maven_get_release_version 1.0.4 minor" {
  function maven_minor_bump() {
    return 0
  }
  function mvn() {
    echo "1 0 4 2 1 5"
  }
  export -f mvn maven_minor_bump
  run maven_get_release_version
  echo $output > /tmp/rikske
  assert_output --partial "1.1.0"
  unset mvn maven_minor_bump
}
