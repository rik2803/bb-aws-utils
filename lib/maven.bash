[[ -z ${LIB_COMMON_LOADED} ]]    && { source ${LIB_DIR:-lib}/common.bash; }
[[ -z ${LIB_GIT_LOADED} ]]       && { source ${LIB_DIR:-lib}/git.bash; }

export LIB_MAVEN_LOADED=1
export MAVEN_VERSION_VARS_SET=0

# MAVEN_SETTINGS_EMAIL: use NA if not required in settings.xml for an index in the array
maven_create_settings_xml() {
  if [[ -e "${MAVEN_SETTINGS_PATH}/settings.xml" ]]; then
    info "${MAVEN_SETTINGS_PATH}/settings.xml already exists"
  else
    info "Start creation of settings.xml"
    check_envvar MAVEN_SETTINGS_ID O 'skip'
    check_envvar MAVEN_SETTINGS_USERNAME O 'skip'
    check_envvar MAVEN_SETTINGS_PASSWORD O 'skip'
    check_envvar MAVEN_SETTINGS_EMAIL O 'skip'
    check_envvar MAVEN_SETTINGS_PATH O /

    local MAVEN_SETTINGS_ID_ARRAY=(${MAVEN_SETTINGS_ID})
    local MAVEN_SETTINGS_USERNAME_ARRAY=(${MAVEN_SETTINGS_USERNAME})
    local MAVEN_SETTINGS_PASSWORD_ARRAY=(${MAVEN_SETTINGS_PASSWORD})
    local MAVEN_SETTINGS_EMAIL_ARRAY=(${MAVEN_SETTINGS_EMAIL})

    {
      echo "<settings>"
      echo "  <servers>"
      if [[ -n ${CODEARTIFACT_AUTH_TOKEN} ]]; then
        echo '    <server>'
        echo '        <id>codeartifact</id>'
        echo '        <username>aws</username>'
        echo '        <password>${env.CODEARTIFACT_AUTH_TOKEN}</password>'
        echo '    </server>'
      fi
      if [[ ${MAVEN_SETTINGS_ID} != skip ]]; then
        for index in "${!MAVEN_SETTINGS_ID_ARRAY[@]}"; do
          echo "    <server>"
          echo "      <id>${MAVEN_SETTINGS_ID_ARRAY[$index]}</id>"
          echo "      <username>${MAVEN_SETTINGS_USERNAME_ARRAY[$index]}</username>"
          echo "      <password>${MAVEN_SETTINGS_PASSWORD_ARRAY[$index]}</password>"
          if [[ ${MAVEN_SETTINGS_EMAIL_ARRAY[$index]} != "NA" ]]; then
            echo "      <configuration>"
            echo "        <email>${MAVEN_SETTINGS_EMAIL_ARRAY[$index]}</email>"
            echo "      </configuration>"
          fi
          echo "      <filePermissions>664</filePermissions>"
          echo "      <directoryPermissions>775</directoryPermissions>"
          echo "    </server>"
        done
      fi
      echo "  </servers>"
      echo "</settings>"
    } > "${MAVEN_SETTINGS_PATH}/settings.xml"
  fi
  if is_debug_enabled; then
    debug "Dump of content of ${MAVEN_SETTINGS_PATH}/settings.xml -- start"
    cat ${MAVEN_SETTINGS_PATH}/settings.xml
    debug "Dump of content of ${MAVEN_SETTINGS_PATH}/settings.xml -- end"
  fi
}

maven_minor_bump() {
  check_envvar MAVEN_MINOR_BUMP_STRING O "bump_minor_version"

  if git_current_commit_message | grep -q "${MAVEN_MINOR_BUMP_STRING}"; then
    return 0
  else
    return 1
  fi
}

maven_set_version_vars() {
  if [[ ${MAVEN_VERSION_VARS_SET} -eq 0 ]]; then
    maven_create_settings_xml
    set -- $(mvn -s "${MAVEN_SETTINGS_PATH}/settings.xml" build-helper:parse-version -q -Dexec.executable=echo -Dexec.args='${parsedVersion.majorVersion} ${parsedVersion.minorVersion} ${parsedVersion.incrementalVersion} ${parsedVersion.nextMajorVersion} ${parsedVersion.nextMinorVersion} ${parsedVersion.nextIncrementalVersion}' --non-recursive exec:exec)
    export MAVEN_MAJOR=${1}; shift
    export MAVEN_MINOR=${1}; shift
    export MAVEN_INCR=${1}; shift
    export MAVEN_NEXT_MAJOR=${1}; shift
    export MAVEN_NEXT_MINOR=${1}; shift
    export MAVEN_NEXT_INCR=${1}
    export MAVEN_VERSION_VARS_SET=1
  else
    info "Maven version variables already set"
  fi
}

maven_save_current_versions() {
  # Run during release build
  [[ -z ${1} || -z ${2} ]] && \
    fail "maven_save_current_versions release_version snapshot_version"

  local maven_release_version=${1}; shift
  local maven_snapshot_version=${1}; shift
  local target_dir=${BITBUCKET_CLONE_DIR:-./}/artifacts

  mkdir -p "${target_dir}"
  {
    echo "export MAVEN_CURRENT_SNAPSHOT_VERSION=${maven_snapshot_version}"
    echo "export MAVEN_CURRENT_RELEASE_VERSION=${maven_release_version}"
  } > "${target_dir}/MAVEN_CURRENT_VERSION"

  # Also set the envvars
  export MAVEN_CURRENT_SNAPSHOT_VERSION=${maven_snapshot_version}
  export MAVEN_CURRENT_RELEASE_VERSION=${maven_release_version}

  info "MAVEN_CURRENT_SNAPSHOT_VERSION=${maven_snapshot_version}"
  info "MAVEN_CURRENT_RELEASE_VERSION=${maven_release_version}"
}

maven_get_current_versions() {
  # Run during deploy
  # Check artifacts/MAVEN_CURRENT_VERSION first
  # If not found (expired and deleted), check the envvar MAVEN_CURRENT_RELEASE_VERSION
  # If not set: log an error and stop
  local target_dir=${BITBUCKET_CLONE_DIR:-./}/artifacts

  info "Trying to retrieve current versions from the build artifacts ..."
  if [[ -e "${target_dir}/MAVEN_CURRENT_VERSION" ]]; then
    info "Build artifacts still present, sourcing ./artifacts/MAVEN_CURRENT_VERSION"
    source "${target_dir}/MAVEN_CURRENT_VERSION"
    success "Successfully sourced ./artifacts/MAVEN_CURRENT_VERSION"
  else
    warning "./artifacts/MAVEN_CURRENT_VERSION not found, probably expired."
    warning "Trying repository envvar MAVEN_CURRENT_RELEASE_VERSION now ..."
  fi

  if [[ -z ${MAVEN_CURRENT_RELEASE_VERSION} ]]; then
    warning "MAVEN_CURRENT_RELEASE_VERSION not available from BB artifacts, this might result in artifact tags or names not containing the correct maven version."
  fi

  if [[ -z ${MAVEN_CURRENT_SNAPSHOT_VERSION} ]]; then
    warning "MAVEN_CURRENT_SNAPSHOT_VERSION not available from BB artifacts, this might result in artifact tags or names not containing the correct maven version."
  fi

  info "MAVEN_CURRENT_SNAPSHOT_VERSION=${MAVEN_CURRENT_SNAPSHOT_VERSION:-NOT FOUND}"
  info "MAVEN_CURRENT_RELEASE_VERSION=${MAVEN_CURRENT_RELEASE_VERSION:-NOT FOUND}"
}

maven_get_next_release_version() {
  maven_set_version_vars
  if maven_minor_bump; then
    RELEASE_VERSION="${MAVEN_MAJOR}.${MAVEN_NEXT_MINOR}.0"
  else
    RELEASE_VERSION="${MAVEN_MAJOR}.${MAVEN_MINOR}.${MAVEN_INCR}"
  fi
  info "Release version is ${RELEASE_VERSION}"
}

maven_get_next_develop_version() {
  maven_set_version_vars
  if maven_minor_bump; then
    DEVELOP_VERSION="${MAVEN_MAJOR}.${MAVEN_NEXT_MINOR}.1-SNAPSHOT"
  else
    DEVELOP_VERSION="${MAVEN_MAJOR}.${MAVEN_MINOR}.${MAVEN_NEXT_INCR}-SNAPSHOT"
  fi
  info "Develop version is ${DEVELOP_VERSION}"
}

maven_get_current_version_from_pom() {
  MAVEN_CURRENT_VERSION_FROM_POM=$(mvn -q -DforceStdout help:evaluate -Dexpression=project.version)
  export MAVEN_CURRENT_VERSION_FROM_POM
}

maven_get_saved_current_version() {
  if [[ -e ${BITBUCKET_CLONE_DIR}/artifacts/curversion ]]; then
    cat ${BITBUCKET_CLONE_DIR}/artifacts/curversion
    return 0
  else
    info "Cannot determine current version because ${BITBUCKET_CLONE_DIR}/artifacts/curversion does not exist."
    return 1
  fi
}

maven_build() {
  check_envvar MAVEN_DEVELOP_COMMAND O "clean deploy"
  check_envvar MAVEN_EXTRA_ARGS O " "
  check_envvar MAVEN_SETTINGS_PATH O /
  check_command mvn || install_sw maven

  info "Retrieving the version number from the pom file"
  maven_get_current_version_from_pom
  info "Finished retrieving the version number from the pom file"

  COMMAND="mvn ${MAVEN_DEVELOP_COMMAND} -B -s ${MAVEN_SETTINGS_PATH}/settings.xml -DscmCommentPrefix=\"[skip ci]\" ${MAVEN_EXTRA_ARGS}"

  info "${COMMAND}"
  eval ${COMMAND}
  success "mvn successfully executed"
  maven_save_current_versions "NA" "${MAVEN_CURRENT_VERSION_FROM_POM}"
}

maven_release_build() {
  check_envvar MAVEN_RELEASE_COMMAND O "release:prepare release:perform"
  check_envvar MAVEN_EXTRA_ARGS O " "
  check_envvar MAVEN_SETTINGS_PATH O /
  check_envvar MAVEN_BRANCH O master
  check_command mvn || install_sw maven

  maven_get_next_release_version
  maven_get_next_develop_version

  git remote set-url origin "${BITBUCKET_GIT_SSH_ORIGIN}"
  git config --global --add status.displayCommentPrefix true

  info "Checking out branch ${MAVEN_BRANCH}"
  git checkout "${MAVEN_BRANCH}"
  success "Successfully checked out ${MAVEN_BRANCH}"

  COMMAND="mvn -B -s ${MAVEN_SETTINGS_PATH}/settings.xml ${MAVEN_EXTRA_ARGS} -Dresume=false \
      -DreleaseVersion=${RELEASE_VERSION} \
      -DdevelopmentVersion=${DEVELOP_VERSION} \
      -DscmCommentPrefix='[skip ci]' \
      ${MAVEN_RELEASE_COMMAND}"

  info "${COMMAND}"
  eval ${COMMAND}
  success "mvn successfully executed"
  maven_save_current_versions "${RELEASE_VERSION}" "${DEVELOP_VERSION}"
}

maven_deploy() {
  check_envvar MAVEN_DEVELOP_COMMAND O "clean deploy"
  check_envvar MAVEN_EXTRA_ARGS O " "
  check_envvar MAVEN_SETTINGS_PATH O /
  check_command mvn || install_sw maven

  COMMAND="mvn ${MAVEN_DEVELOP_COMMAND} -B -s ${MAVEN_SETTINGS_PATH}/settings.xml -DscmCommentPrefix=\"[skip ci]\" ${MAVEN_EXTRA_ARGS}"

  info "${COMMAND}"
  eval ${COMMAND}
  success "mvn successfully executed"
  maven_save_current_versions "NA" "$(mvn -q -DforceStdout help:evaluate -Dexpression=project.version)"
}

maven_release_deploy() {
  check_envvar MAVEN_EXTRA_ARGS O " "
  check_envvar MAVEN_SETTINGS_PATH O /
  check_envvar MAVEN_BRANCH O master
  check_command mvn || install_sw maven

  git remote set-url origin "${BITBUCKET_GIT_SSH_ORIGIN}"
  git config --global --add status.displayCommentPrefix true

  info "Checking out branch ${MAVEN_BRANCH}"
  git checkout "${MAVEN_BRANCH}"
  success "Successfully checked out ${MAVEN_BRANCH}"

  [[ -n ${RELEASE_VERSION_OVERRIDE} ]] && MAVEN_EXTRA_ARGS="-DreleaseVersion=${RELEASE_VERSION_OVERRIDE} ${MAVEN_EXTRA_ARGS}"
  [[ -n ${DEVELOPMENT_VERSION_OVERRIDE} ]] && MAVEN_EXTRA_ARGS="-DdevelopmentVersion=${DEVELOPMENT_VERSION_OVERRIDE} ${MAVEN_EXTRA_ARGS}"
  ## release:prepare
  COMMAND="mvn -B -s ${MAVEN_SETTINGS_PATH}/settings.xml ${MAVEN_EXTRA_ARGS} -Dresume=false \
      -DscmCommentPrefix='[skip ci]' release:prepare"
  info "${COMMAND}"
  eval ${COMMAND}
  success "mvn release:prepare successfully executed"
  info "Retrieving project.version ..."
  maven_get_current_version_from_pom
  RELEASE_VERSION="${MAVEN_CURRENT_VERSION_FROM_POM}"
  success "project.version=${RELEASE_VERSION}"

  ## release:perform
  COMMAND="mvn -B -s ${MAVEN_SETTINGS_PATH}/settings.xml ${MAVEN_EXTRA_ARGS} -Dresume=false \
      -DscmCommentPrefix='[skip ci]' release:perform"
  info "${COMMAND}"
  eval ${COMMAND}
  success "mvn release:perform successfully executed"
  info "Retrieving project.version ..."
  maven_get_current_version_from_pom
  DEVELOPMENT_VERSION="${MAVEN_CURRENT_VERSION_FROM_POM}"
  success "project.version=${DEVELOPMENT_VERSION}"

  maven_save_current_versions "${RELEASE_VERSION}" "${DEVELOPMENT_VERSION}"
}
