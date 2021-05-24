export LIB_COMMON_LOADED=1

# Begin Standard 'imports'
set -e
set -o pipefail

gray="\\e[37m"
blue="\\e[36m"
red="\\e[31m"
green="\\e[32m"
orange="\\e[33m"
reset="\\e[0m"

info()    { echo -e "${blue}INFO: $*${reset}" 1>&2; }
warning() { echo -e "${orange}WARN: $*${reset}" 1>&2; }
error()   { echo -e "${red}ERROR: $*${reset}" 1>&2; }
success() { echo -e "${green}✔ $*${reset}" 1>&2; }
fail()    { echo -e "${red}✖ $*${reset}" 1>&2; exit 1; }
debug()   { [[ "${DEBUG}" == "true" ]] && echo -e "${gray}DEBUG: $*${reset}"  1>&2 || true; }

## Enable debug mode.
enable_debug() {
  if [[ "${DEBUG}" == "true" ]]; then
    info "Enabling debug mode."
    set -x
  fi
}

is_debug_enabled() {
  if [[ "${DEBUG}" == "true" ]]; then
    return 0
  else
    return 1
  fi
}

#######################################
# Check if a command exists
#
# Globals:
#
# Arguments:
#   command:  The name of the command
#
# Returns:
#   None
#######################################
check_command() {
  if ! command -v "${1:-not_present}" >/dev/null 2>&1; then
    warning "Command ${1} is required but not found."
    return 1
  else
    success "Command ${1} is available"
    return 0
  fi
}

#######################################
# Check required or optional envvars and set
# default value for optional envvars, and exits
# in case of error.
#
# Globals:
#
# Arguments:
#   envvar:  The name of the variable
#   mode:    O or R (Optional or Required), "R" if not passed
#   default: default value if optional envvar is not set
#            required for optional envvars
# Returns:
#   None
#######################################
check_envvar() {
  local envvar
  local mode
  local default
  info "Start checking envvar ${*}"
  ### Check first argument: name of the envvar
  if [[ -n ${1} ]]; then
    envvar=${1}
    shift
    debug "envvar = ${envvar}"
  else
    fail "check_envvar(): first argument (envvar) is required"
  fi

  ### Check second argument: R(equired) or O(ptional)
  if [[ -n ${1} ]]; then
    if [[ ${1} = R || ${1} = O ]]; then
      mode=${1}
      shift
      debug "check_envvar(): mode = ${mode}"
    else
      fail "check_envvar(): second argument (mode) is should be O or R"
    fi
  else
    debug "check_envvar(): mode not passed, assume R(equired)"
    mode="R"
  fi

  ### Check 3rd argument: default value for optional envvars
  if [[ "${mode}" = "O" ]]; then
    if [[ -n ${1} ]]; then
      default=${1}
      shift
      debug "check_envvar(): default = \"${default}\""
    else
      fail "check_envvar(): default value is required for optional envvars"
    fi
  else
    debug "check_envvar(): default value not required for required envvars"
  fi

  eval check="\$$envvar"

  if [[ "${mode}" = "R" && -z $check ]]; then
    fail "check_envvar(): Required envvar ${envvar} is not set"
  elif [[ "${mode}" = "O" && -z $check ]]; then
    eval export $envvar=\"$default\"
    debug "check_envvar(): Optional envvar ${envvar} set to default value \"${default}\""
  fi

  success "Envvar $envvar successfully verified"
}

# Execute a command, saving its exit status code.
# Globals set:
#   run_status: Exit status of the command that was executed.
#
run_cmd() {
  set +e
  $@ 2>&1
  run_status=$?
  set -e
}

# End standard 'imports'
