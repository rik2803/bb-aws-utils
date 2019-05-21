source lib/common.bash
source lib/git.bash

maven_create_settings_xml() {
  check_envvar MAVEN_SETTINGS_ID R
  check_envvar MAVEN_SETTINGS_USERNAME R
  check_envvar MAVEN_SETTINGS_PASSWORD R
  check_envvar MAVEN_SETTINGS_PATH O /

  MAVEN_SETTINGS_ID_ARRAY=(${MAVEN_SETTINGS_ID})
  MAVEN_SETTINGS_USERNAME_ARRAY=(${MAVEN_SETTINGS_USERNAME})
  MAVEN_SETTINGS_PASSWORD_ARRAY=(${MAVEN_SETTINGS_PASSWORD})

  echo "<settings>" > ${MAVEN_SETTINGS_PATH}/settings.xml
  echo "  <servers>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
  for index in "${!MAVEN_SETTINGS_ID_ARRAY[@]}"; do
    echo "    <server>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
    echo "      <id>${MAVEN_SETTINGS_ID_ARRAY[$index]}</id>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
    echo "      <username>${MAVEN_SETTINGS_USERNAME_ARRAY[$index]}</username>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
    echo "      <password>${MAVEN_SETTINGS_PASSWORD_ARRAY[$index]}</password>" >> ${MAVEN_SETTINGS_PATH}/settings.xml
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

  run mvn ${MAVEN_COMMAND} -s ${MAVEN_SETTINGS_PATH}/settings.xml ${MAVEN_EXTRA_ARGS}
}

maven_minor_bump() {
  check_envvar MAVEN_MINOR_BUMP_STRING O "bump_minor_version"

  run git_current_commit_message
  if [[ ${output} =~ ${MAVEN_MINOR_BUMP_STRING} ]]; then
    return 1
  else
    return 0
  fi 
}

maven_release_build() {
  check_envvar MAVEN_COMMAND O "clean deploy"
  check_envvar MAVEN_EXTRA_ARGS O " "
  check_envvar MAVEN_SETTINGS_PATH O /
  check_command mvn

  if maven_minor_bump; then
    run mvn build-helper:parse-version -q -Dexec.executable=echo \
            -Dexec.args='${parsedVersion.majorVersion}.${parsedVersion.nextMinorVersion}.0' \
            --non-recursive exec:exec
    RELEASE_VERSION=${output}
    run mvn build-helper:parse-version -q -Dexec.executable=echo \
            -Dexec.args='${parsedVersion.majorVersion}.${parsedVersion.nextMinorVersion}.1' \
            --non-recursive exec:exec
    DEVELOP_VERSION="${output}-SNAPSHOT"
  else
    run mvn build-helper:parse-version -q -Dexec.executable=echo \
            -Dexec.args='${parsedVersion.majorVersion}.${parsedVersion.minorVersion}.${parsedVersion.incrementalVersion}' \
            --non-recursive exec:exec
    RELEASE_VERSION=${output}
    run mvn build-helper:parse-version -q -Dexec.executable=echo \
            -Dexec.args='${parsedVersion.majorVersion}.${parsedVersion.minorVersion}.${parsedVersion.nextIncrementalVersion}' \
            --non-recursive exec:exec
    DEVELOP_VERSION="${output}-SNAPSHOT"
  fi

  mvn -B -s ${MAVEN_SETTINGS_PATH}/settings.xml ${MAVEN_EXTRA_ARGS} -Dresume=false \
      -DreleaseVersion="${RELEASE_VERSION}" \
      -DdevelopmentVersion="${DEVELOP_VERSION}" \
      ${MAVEN_COMMAND}
}
