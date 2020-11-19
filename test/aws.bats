#!/usr/bin/env bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
  source "${LIB_DIR}/common.bash"
  source "${LIB_DIR}/aws.bash"
  AWS_CREDENTIALS_JSON='{"profiles":[{"name":"default","role_arn":"arn:aws:iam::123456789012:role/ServiceAccount/cicd","aws_access_key_id":"AKIA","aws_secret_access_key":"sdkf"},{"name":"tst","role_arn":"arn:aws:iam::123456789012:role/ServiceAccount/cicd","aws_access_key_id":"AKIAXXXXXXXXXXXXXXX","aws_secret_access_key":"sdkfjasldfhasjdflashkjfdklasjhdfaklsdfhjaskjlf"},{"name":"stg","role_arn":"arn:aws:iam::123456789012:role/ServiceAccount/cicd","aws_access_key_id":"AKIAXXXXXXXXXXXXXXX","aws_secret_access_key":"sdkfjasldfhasjdflashkjfdklasjhdfaklsdfhjaskjlf"},{"name":"prd","role_arn":"arn:aws:iam::123456789012:role/ServiceAccount/cicd","aws_access_key_id":"AKIAXXXXXXXXXXXXXXX","aws_secret_access_key":"sdkfjasldfhasjdflashkjfdklasjhdfaklsdfhjaskjlf"}]}'
  AWS_CONFIG_BASEDIR=~/tmp/.aws
}

teardown() {
  true
#  rm -rf ${AWS_CONFIG_BASEDIR}
}

@test "true" {
  run true
  assert_success
}

@test "aws_serviceaccount_create_credentials" {
  function command() {
    if [ ${2} = "jq" ]; then
      return 0
    else
      return 1
    fi
  }
  export -f command
  run aws_set_service_account_config
  assert_success
  unset command
}
