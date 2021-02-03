[[ -z ${LIB_COMMON_LOADED} ]] && { source "${LIB_DIR:-lib}/common.bash"; }
LIB_INSTALL_LOADED=1

CENTOSDISTRO=0
DEBIANDISTRO=0
ALPINEDISTRO=0
AWSCLI_INSTALLED=0
ZIP_INSTALLED=0
JQ_INSTALLED=0
APT_GET_UPDATE_OK=0

install_set_linux_distribution_type() {
  if command -v yum > /dev/null 2>&1; then
    CENTOSDISTRO=1
  elif command -v apt-get > /dev/null 2>&1; then
    DEBIANDISTRO=1
  elif command -v apk > /dev/null 2>&1; then
    ALPINEDISTRO=1
  fi

  info "CENTOSDISTRO=${CENTOSDISTRO}"
  info "DEBIANDISTRO=${DEBIANDISTRO}"
  info "ALPINEDISTRO=${ALPINEDISTRO}"
}

run_log_and_exit_on_failure() {
  info "${FUNCNAME[0]} - Starting ${1}"
  if eval "${1}"
  then
    success "${FUNCNAME[0]} - ${1} successfully executed"
  else
    _enable_cw_alarms
    fail "${FUNCNAME[0]} - ${1} failed, exiting ..."
  fi
}

run_apt_get_update() {
  if [[ ${APT_GET_UPDATE_OK} -eq 0 ]]
  then
    # To avoid error on jessie and archived jessie-updates/main
    sed -i '/jessie-updates/d' /etc/apt/sources.list || true
    run_log_and_exit_on_failure "apt-get -qq update"
    APT_GET_UPDATE_OK=1
  fi
}

install_sw() {
  info "Installing ${1}"

  [[ -z ${1} ]] && fail "install_sw sw_to_install"

  if [[ ${CENTOSDISTRO} = "1" ]]; then
    yum -y -q install "${1}"
  elif [[ ${DEBIANDISTRO} = "1" ]]; then
    apt-get -qq update && apt-get -qq -y install "${1}"
  elif [[ ${ALPINEDISTRO} = "1" ]]; then
    apk --quiet --update --no-cache add "${1}"
  else
    info "Unknown distribution, continuing without installing ${1}"
  fi

  success "Successfully installed ${1}"
}

install_apt_get_update() {
  if [[ ${APT_GET_UPDATE_OK} -eq 0 ]]
  then
    # To avoid error on jessie and archived jessie-updates/main
    sed -i '/jessie-updates/d' /etc/apt/sources.list || true
    apt-get -qq update
    APT_GET_UPDATE_OK=1
  fi
}

remove_awscli_v1() {
  true
}

install_awscli() {
  info "Installing AWS CLI v2 (if not already installed)"

  local AWSCLI_V1_INSTALLED=0

  if command -v aws > /dev/null 2>&1; then
    if aws --version | grep -q "aws-cli/2"; then
      AWSCLI_INSTALLED=1
    else
      AWSCLI_V1_INSTALLED=1
    fi
  fi

  if [[ ${AWSCLI_V1_INSTALLED} -eq 1 ]]; then
    info "AWS CLI v1 is installed, removing ..."
    remove_awscli_v1
  fi

  if [[ ${AWSCLI_INSTALLED} -eq 0 ]]; then
    mkdir -p /tmp
    install_sw curl
    install_zip
    run_cmd curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    run_cmd unzip -q awscliv2.zip -d /tmp
    run_cmd /tmp/aws/install
    [[ ${PATH} = "*/usr/local/bin*" ]] || export PATH="/usr/local/bin:${PATH}"
  else
    info "${FUNCNAME[0]} - awscli already installed"
  fi
}

install_zip() {
  if [[ ${ZIP_INSTALLED} -eq 0 ]]
  then
    if [[ ${DEBIANDISTRO} -eq 1 ]]
    then
      info "${FUNCNAME[0]} - Installing zip on debian"
      run_apt_get_update
      run_log_and_exit_on_failure "apt-get -qq -y install zip"
      ZIP_INSTALLED=1
    else
      info "${FUNCNAME[0]} - Installing zip on CentOS"
      run_log_and_exit_on_failure "yum -y -q install zip unzip"
      ZIP_INSTALLED=1
    fi
  else
    echo "${FUNCNAME[0]} - zip already installed"
  fi
}

install_maven2() {
  info "${FUNCNAME[0]} - Start maven2 installation"
  if [[ ${DEBIANDISTRO} -eq 1 ]]
  then
    run_apt_get_update
    run_log_and_exit_on_failure "apt-get -qq -y install maven2"
  else
    info "${FUNCNAME[0]} - Installing maven2 on CentOS like distro is not implemented"
  fi
}

install_jq() {
  if [[ ${JQ_INSTALLED} -eq 0 ]]
  then
    info "${FUNCNAME[0]} - Start jq installation"
    if [[ ${DEBIANDISTRO} -eq 1 ]]
    then
      run_apt_get_update
      run_log_and_exit_on_failure "apt-get -qq -y install jq"
    else
      run_log_and_exit_on_failure "yum -y -q install jq"
    fi

    ### jq is required
    if ! command -v jq >/dev/null 2>&1
    then
      fail "${FUNCNAME[0]} - jq is required"
    else
      success "${FUNCNAME[0]} - jq is installed"
      JQ_INSTALLED=1
    fi
  else
    info "${FUNCNAME[0]} - jq already installed"
  fi
}

install_set_linux_distribution_type
