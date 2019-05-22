source ${LIB_DIR:-lib}/common.bash
source ${LIB_DIR:-lib}/git.bash

# MAVEN_SETTINGS_EMAIL: use NA if not required in settings.xml for an index in the array
maven_create_settings_xml() {
  info "Start creation of settings.xml"
  check_envvar MAVEN_SETTINGS_ID R
  check_envvar MAVEN_SETTINGS_USERNAME R
  check_envvar MAVEN_SETTINGS_PASSWORD R
  check_envvar MAVEN_SETTINGS_EMAIL R
  check_envvar MAVEN_SETTINGS_PATH O /

  MAVEN_SETTINGS_ID_ARRAY=(${MAVEN_SETTINGS_ID})
  MAVEN_SETTINGS_USERNAME_ARRAY=(${MAVEN_SETTINGS_USERNAME})
  MAVEN_SETTINGS_PASSWORD_ARRAY=(${MAVEN_SETTINGS_PASSWORD})
  MAVEN_SETTINGS_EMAIL_ARRAY=(${MAVEN_SETTINGS_EMAIL})

  echo "<settings>" > ${MAVEN_SETTINGS_PATH}/settings.xml
  echo "  <servers>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
  for index in "${!MAVEN_SETTINGS_ID_ARRAY[@]}"; do
    echo "    <server>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
    echo "      <id>${MAVEN_SETTINGS_ID_ARRAY[$index]}</id>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
    echo "      <username>${MAVEN_SETTINGS_USERNAME_ARRAY[$index]}</username>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
    echo "      <password>${MAVEN_SETTINGS_PASSWORD_ARRAY[$index]}</password>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
    if [[ ${MAVEN_SETTINGS_EMAIL_ARRAY[$index]} != "NA" ]]; then
      echo "      <configuration>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
      echo "        <email>${MAVEN_SETTINGS_EMAIL_ARRAY[$index]}</email>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
      echo "      </configuration>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
    fi
    echo "      <filePermissions>664</filePermissions>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
    echo "      <directoryPermissions>775</directoryPermissions>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
    echo "    </server>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
  done
  echo "  </servers>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
  echo "</settings>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
}

maven_build() {
  check_envvar MAVEN_COMMAND O "clean deploy"
  check_envvar MAVEN_EXTRA_ARGS O " "
  check_envvar MAVEN_SETTINGS_PATH O /
  check_command mvn

  COMMAND="mvn ${MAVEN_COMMAND} -s ${MAVEN_SETTINGS_PATH}/settings.xml -DscmCommentPrefix='[skip ci]' ${MAVEN_EXTRA_ARGS}"

  info "${COMMAND}"
  ${COMMAND}
}

maven_minor_bump() {
  check_envvar MAVEN_MINOR_BUMP_STRING O "bump_minor_version"

  if git_current_commit_message | grep -q ${MAVEN_MINOR_BUMP_STRING}; then
    return 0
  else
    return 1
  fi
}

maven_set_versions() {
    set -- $(mvn build-helper:parse-version -q -Dexec.executable=echo -Dexec.args='${parsedVersion.majorVersion} ${parsedVersion.minorVersion} ${parsedVersion.incrementalVersion} ${parsedVersion.nextMajorVersion} ${parsedVersion.nextMinorVersion} ${parsedVersion.nextIncrementalVersion}' --non-recursive exec:exec)
    export MAVEN_MAJOR=${1}; shift
    export MAVEN_MINOR=${1}; shift
    export MAVEN_INCR=${1}; shift
    export MAVEN_NEXT_MAJOR=${1}; shift
    export MAVEN_NEXT_MINOR=${1}; shift
    export MAVEN_NEXT_INCR=${1}
}

maven_get_release_version() {
  maven_set_versions
  if maven_minor_bump; then
    RELEASE_VERSION="${MAVEN_MAJOR}.${MAVEN_NEXT_MINOR}.0"
  else
    RELEASE_VERSION="${MAVEN_MAJOR}.${MAVEN_MINOR}.${MAVEN_INCR}"
  fi
  info "Release version is ${RELEASE_VERSION}"
}

maven_get_develop_version() {
  maven_set_versions
  if maven_minor_bump; then
    DEVELOP_VERSION="${MAVEN_MAJOR}.${MAVEN_NEXT_MINOR}.1-SNAPSHOT"
  else
    DEVELOP_VERSION="${MAVEN_MAJOR}.${MAVEN_MINOR}.${MAVEN_NEXT_INCR}-SNAPSHOT"
  fi
  info "Develop version is ${DEVELOP_VERSION}"
}

maven_release_build() {
  check_envvar MAVEN_COMMAND O "clean deploy"
  check_envvar MAVEN_EXTRA_ARGS O " "
  check_envvar MAVEN_SETTINGS_PATH O /
  check_envvar MAVEN_BRANCH O master
  check_command mvn

  maven_set_versions

  maven_get_release_version
  maven_get_develop_version

  git checkout ${MAVEN_BRANCH}

 COMMAND="mvn -B -s ${MAVEN_SETTINGS_PATH}/settings.xml ${MAVEN_EXTRA_ARGS} -Dresume=false \
      -DreleaseVersion=${RELEASE_VERSION} \
      -DscmCommentPrefix='[skip ci]' \
      -DdevelopmentVersion=${DEVELOP_VERSION} \
      ${MAVEN_COMMAND}"

  info "${COMMAND}"
  ${COMMAND}
}
