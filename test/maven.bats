#!/usr/bin/env bats

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
  [ $status = 0 ]
  [ $lines = 25 ]
}

@test "maven_minor_bump true" {
  run maven_minor_bump
  [ $status = 0 ]
}
