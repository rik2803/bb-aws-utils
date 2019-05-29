#!/usr/bin/env bats

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
  source "./lib/install.bash"
  source "./lib/maven.bash"
}

teardown() {
  true
}

@test "install_set_linux_distribution_type CENTOS" {
  function which() {
    if [ ${1} = "yum" ]; then
      return 0
    else
      return 1
    fi
  }
  export -f which
  run install_set_linux_distribution_type
  assert_output --partial "CENTOSDISTRO=1"
  assert_output --partial "DEBIANDISTRO=0"
  assert_output --partial "ALPINEDISTRO=0"
  unset which
}

@test "install_set_linux_distribution_type DEBIAN" {
  function which() {
    if [ ${1} = "apt-get" ]; then
      return 0
    else
      return 1
    fi
  }
  export -f which
  run install_set_linux_distribution_type
  assert_output --partial "CENTOSDISTRO=0"
  assert_output --partial "DEBIANDISTRO=1"
  assert_output --partial "ALPINEDISTRO=0"
  unset which
}

@test "install_set_linux_distribution_type ALPINE" {
  function which() {
    if [ ${1} = "apk" ]; then
      return 0
    else
      return 1
    fi
  }
  export -f which
  run install_set_linux_distribution_type
  assert_output --partial "CENTOSDISTRO=0"
  assert_output --partial "DEBIANDISTRO=0"
  assert_output --partial "ALPINEDISTRO=1"
  unset which
}

@test "install_sw jq" {
  export CENTOSDISTRO=1
  export DEBIANDISTRO=0
  function yum() { echo "success"; }
  run install_sw jq
  assert_output --partial "success"
  unset yum
}
