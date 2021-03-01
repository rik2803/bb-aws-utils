#!/usr/bin/env bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
  source "${LIB_DIR}/common.bash"
  source "${LIB_DIR}/aws.bash"
  AWS_CONFIG_BASEDIR=~/tmp/.aws
  SA_ACCOUNT_LIST="IXOR_SANDBOX IXOR_SANDBOX2 IXOR_SANDBOX3"
  ACCESS_KEY_ID_IXOR_SANDBOX="AKIA_IXOR_SANDBOX"
  ACCESS_KEY_ID_IXOR_SANDBOX2="AKIA_IXOR_SANDBOX2"
  ACCESS_KEY_ID_IXOR_SANDBOX3="AKIA_IXOR_SANDBOX3"
  SECRET_ACCESS_KEY_IXOR_SANDBOX="sandbox-aaaaaaaaaaaaaaaaaaaaaaa"
  SECRET_ACCESS_KEY_IXOR_SANDBOX2="sandbox2-bbbbbbbbbbbbbbbbbbbbbb"
  SECRET_ACCESS_KEY_IXOR_SANDBOX3="sandbox3-cccccccccccccccccccccc"
  ACCOUNT_ID_IXOR_SANDBOX="111111111111"
  ACCOUNT_ID_IXOR_SANDBOX2="222222222222"
  ACCOUNT_ID_IXOR_SANDBOX3="333333333333"
  AWS_ROLE_TO_ASSUME_IXOR_SANDBOX="arn:aws:iam::111111111111:role/ServiceAccount/cicd"
  AWS_ROLE_TO_ASSUME_IXOR_SANDBOX2="arn:aws:iam::222222222222:role/ServiceAccount/cicd"
  AWS_ROLE_TO_ASSUME_IXOR_SANDBOX3="arn:aws:iam::333333333333:role/ServiceAccount/cicd"
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

@test "_indirection_01" {
  basename_var="AWS_ACCESS_KEY_ID"
  account="IXOR_SANDBOX"
  AWS_ACCESS_KEY_ID_IXOR_SANDBOX=AKIA123456789012
  result=$(_indirection "${basename_var}" "${account}")
  assert_equal "${result}" "${AWS_ACCESS_KEY_ID_IXOR_SANDBOX}"
}

@test "_indirection_emtpy_string_when_var_does_not_exist_01" {
  basename_var="AWS_ACCESS_KEY_ID"
  account="IXOR_SANDBOX"
  unset AWS_ACCESS_KEY_ID_IXOR_SANDBOX
  result=$(_indirection "${basename_var}" "${account}")
  assert_equal "${result}" "" "Expecting empty result when envvar does not exist"
}
#
#@test "aws_force_restart_service_no_such_service" {
#  function aws() {
#    echo ""
#  }
#  export -f aws
#  run aws_force_restart_service clustername servicename
#  assert_failure "aws_force_restart_service should fail when service is not found"
#  unset aws
#}
#
#@test "aws_force_restart_service_01" {
#  function aws() {
#    if [[ ${2} == "list-services" ]]; then
#      echo "Service-myService"
#    elif [[ ${2} == "update-service" ]]; then
#      return 0
#    fi
#  }
#  export -f aws
#  run aws_force_restart_service clustername myService
#  assert_success "aws_force_restart_service failed"
#  unset aws
#}