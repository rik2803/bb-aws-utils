# shellcheck source=../../bb-aws-utils/lib/common.bash
[[ -z ${LIB_COMMON_LOADED} ]] && { source "${LIB_DIR:-lib}/common.bash"; }
# shellcheck source=../../bb-aws-utils/lib/git.bash
[[ -z ${LIB_GIT_LOADED} ]]    && { source "${LIB_DIR:-lib}/git.bash"; }

export LIB_GRADLE_LOADED=1

gradle_pass() {
  echo jaja
}

gradle_create_gradle_properties() {
  info "Start creation of ~/.gradle/gradle.properties"
  check_envvar GRADLE_PROPERTY_KEYS O 'skip'
  check_envvar GRADLE_PROPERTY_VALUES O 'skip'

  local GRADLE_PROPERTY_KEYS_ARRAY=(${GRADLE_PROPERTY_KEYS})
  local GRADLE_PROPERTY_VALUES_ARRAY=(${GRADLE_PROPERTY_VALUES})
  local gradle_properties_path=${GRADLE_PROPERTIES_PATH:-~/.gradle}

  info "Create ${gradle_properties_path} directory"
  mkdir -p "${gradle_properties_path}" || true

  if [[ ${GRADLE_PROPERTY_KEYS} != skip ]]; then
    info "Create ${gradle_properties_path}/gradle.properties"
    {
        for index in "${!GRADLE_PROPERTY_KEYS_ARRAY[@]}"; do
          echo "${GRADLE_PROPERTY_KEYS_ARRAY[$index]}=${GRADLE_PROPERTY_VALUES_ARRAY[$index]:-NA}"
        done
    } > "${gradle_properties_path}/gradle.properties"
  else
    info "Skipping creation of ${gradle_properties_path}/gradle.properties because required"
    info "    environment variables are not set."
  fi
}
