[[ -z ${LIB_COMMON_LOADED} ]] && { source ${LIB_DIR:-lib}/common.bash; }
LIB_INSTALL_LOADED=1

CENTOSDISTRO=0
DEBIANDISTRO=0
ALPINEDISTRO=0
AWSCLI_INSTALLED=0
APT_GET_UPDATE_OK=0

install_silently_install_which() {
  # Some Fedora/RHEL based containers do not have which
  # installed, which :-) is used to determine the
  # distribution.
  yum install -y which > /dev/null 2>&1 || true
}

install_set_linux_distribution_type() {
  if which yum > /dev/null 2>&1; then
    CENTOSDISTRO=1
  elif which apt-get > /dev/null 2>&1; then
    DEBIANDISTRO=1
  elif which apk > /dev/null 2>&1; then
    ALPINEDISTRO=1
  fi

  info "CENTOSDISTRO=${CENTOSDISTRO}"
  info "DEBIANDISTRO=${DEBIANDISTRO}"
  info "ALPINEDISTRO=${ALPINEDISTRO}"
}

install_sw() {
  [[ -z ${1} ]] && fail "install_sw sw_to_install"

  if [[ ${CENTOSDISTRO} = "1" ]]; then
    yum install -y ${1}
  elif [[ ${DEBIANDISTRO} = "1" ]]; then
    apt-get update && apt-get install -y ${1}
  elif [[ ${ALPINEDISTRO} = "1" ]]; then
    apk --update --no-cache add ${1}
  else
    info "Unknown distribution, continuing without installing ${1}"
  fi
}

install_apt_get_update() {
  if [[ ${APT_GET_UPDATE_OK} -eq 0 ]]
  then
    # To avoid error on jessie and archived jessie-updates/main
    sed -i '/jessie-updates/d' /etc/apt/sources.list || true
    apt-get update
    APT_GET_UPDATE_OK=1
  fi
}

install_awscli() {
  if which aws > /dev/null 2>&1; then
    AWSCLI_INSTALLED=1
  elif [[ ${AWSCLI_INSTALLED} -eq 0 ]]; then
    if [[ ${DEBIANDISTRO} -eq 1 ]]; then
      info "${FUNCNAME[0]} - Installing aws cli on Debian"
      install_apt_get_update
      apt-get install -y python-dev
      curl -O https://bootstrap.pypa.io/get-pip.py
      python get-pip.py
      pip install awscli
      AWSCLI_INSTALLED=1
    elif [[ ${ALPINEDISTRO} -eq 1 ]]; then
      info "${FUNCNAME[0]} - Installing aws cli on Alpine"
      apk --update --no-cache add python py-pip
      pip install --no-cache-dir awscli
    else
      info "${FUNCNAME[0]} - Installing aws cli on CentOS"
      yum install -y awscli
      AWSCLI_INSTALLED=1
    fi
  else
    info "${FUNCNAME[0]} - awscli already installed"
  fi
}

install_silently_install_which
install_set_linux_distribution_type
