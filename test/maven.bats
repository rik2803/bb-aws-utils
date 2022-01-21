#!/usr/bin/env bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
  export MAVEN_SETTINGS_PATH="/tmp"
  source "${LIB_DIR}/common.bash"
  source "${LIB_DIR}/maven.bash"
  mkdir -p ./artifacts
}

teardown() {
  rm -f ./settings.xml || true
  rm -rf ./artifacts   || true
  unset MAVEN_SETTINGS_PATH
  true
}

@test "maven_create_settings_xml" {
  export MAVEN_SETTINGS_ID="id1 id2 id3"
  export MAVEN_SETTINGS_USERNAME="u1 u2 u3"
  export MAVEN_SETTINGS_PASSWORD="p1 p2 p3"
  export MAVEN_SETTINGS_EMAIL="NA NA NA"
  export MAVEN_SETTINGS_PATH="./"
  run maven_create_settings_xml
  lines=$(cat ${MAVEN_SETTINGS_PATH}/settings.xml | wc -l | tr -d ' ')
  assert_success
  assert_equal $lines 25
  rm -f settings.xml
}

@test "maven_create_settings_xml with 1 email address" {
  export MAVEN_SETTINGS_ID="id1 id2 id3"
  export MAVEN_SETTINGS_USERNAME="u1 u2 u3"
  export MAVEN_SETTINGS_PASSWORD="p1 p2 p3"
  export MAVEN_SETTINGS_EMAIL="email NA NA"
  export MAVEN_SETTINGS_PATH="./"
  run maven_create_settings_xml
  lines=$(cat ${MAVEN_SETTINGS_PATH}/settings.xml | wc -l | tr -d ' ')
  assert_success
  assert_equal $lines 28
  rm -f settings.xml
}

@test "maven_minor_bump true" {
  function git_current_commit_message() { echo "bump_minor_version"; }
  export -f git_current_commit_message
  run maven_minor_bump
  assert_success
  unset git_current_commit_message
}

@test "maven_set_version_vars 1.0.4" {
  function git_current_commit_message() { echo "bump_minor_version"; }
  function mvn() {
    echo "1 0 4 2 1 5"
  }
  export -f mvn git_current_commit_message
  run maven_set_version_vars
  assert_success
  unset mvn git_current_commit_message
}

@test "maven_get_next_develop_version 1.0.4 patch" {
  function maven_minor_bump() {
    return 1
  }
  function mvn() {
    echo "1 0 4 2 1 5"
  }
  export -f mvn maven_minor_bump
  run maven_get_next_develop_version
  echo $output > /tmp/rikske
  assert_output --partial "1.0.5-SNAPSHOT"
  unset mvn maven_minor_bump
}

@test "maven_get_next_release_version 1.0.4 patch" {
  function maven_minor_bump() {
    return 1
  }
  function mvn() {
    echo "1 0 4 2 1 5"
  }
  export -f mvn maven_minor_bump
  run maven_get_next_release_version
  assert_output --partial "1.0.4"
  unset mvn maven_minor_bump
}

@test "maven_get_next_develop_version 1.0.4 minor" {
  function maven_minor_bump() {
    return 0
  }
  function mvn() {
    echo "1 0 4 2 1 5"
  }
  export -f mvn maven_minor_bump
  run maven_get_next_develop_version
  assert_output --partial "1.1.1-SNAPSHOT"
  unset mvn maven_minor_bump
}

@test "maven_get_next_release_version 1.0.4 minor" {
  function maven_minor_bump() {
    return 0
  }
  function mvn() {
    echo "1 0 4 2 1 5"
  }
  export -f mvn maven_minor_bump
  run maven_get_next_release_version
  echo $output > /tmp/rikske
  assert_output --partial "1.1.0"
  unset mvn maven_minor_bump
}

@test "maven_save_current_versions 1.0.4 1.0.5-SNAPSHOT" {
  run maven_save_current_versions 1.0.4 1.0.5-SNAPSHOT
  assert_success
  assert_output --partial "MAVEN_CURRENT_RELEASE_VERSION=1.0.4"
}

@test "maven_save_current_versions 1.0.5 1.0.6-SNAPSHOT" {
  run maven_save_current_versions 1.0.5 1.0.6-SNAPSHOT
  assert_success
  assert_output --partial "MAVEN_CURRENT_SNAPSHOT_VERSION=1.0.6-SNAPSHOT"
}

@test "maven_get_current_versions from artifacts" {
  echo "export MAVEN_CURRENT_RELEASE_VERSION=1.2.3" > artifacts/MAVEN_CURRENT_VERSION
  echo "export MAVEN_CURRENT_SNAPSHOT_VERSION=1.2.4-SNAPSHOT" >> artifacts/MAVEN_CURRENT_VERSION
  run maven_get_current_versions
  echo $status
  echo $output
  assert_success
  assert_output --partial "MAVEN_CURRENT_RELEASE_VERSION=1.2.3"
  assert_output --partial "MAVEN_CURRENT_SNAPSHOT_VERSION=1.2.4-SNAPSHOT"
}

@test "maven_get_current_versions from env" {
  export MAVEN_CURRENT_RELEASE_VERSION=1.2.3
  export MAVEN_CURRENT_SNAPSHOT_VERSION=1.2.4-SNAPSHOT
  run maven_get_current_versions
  assert_success
  assert_output --partial "MAVEN_CURRENT_RELEASE_VERSION=1.2.3"
  assert_output --partial "MAVEN_CURRENT_SNAPSHOT_VERSION=1.2.4-SNAPSHOT"
}
