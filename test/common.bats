#!/usr/bin/env bats

setup() {
  source "./lib/common.bash"
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
  [ $status = 1 ]
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
