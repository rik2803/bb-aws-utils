# shellcheck source=../../bb-aws-utils/lib/common.bash
[[ -z ${LIB_COMMON_LOADED} ]] && { source "${LIB_DIR:-lib}/common.bash"; }
export LIB_SLACK_LOADED=1

slack_post_message_using_webhook() {
  check_envvar SLACK_WEBHOOK_URL R

  install_sw curl

  local title
  local value
  local status # good|warning|danger
  local fallback
  local pretext
  local json_string

  title="${1:-No Title}"
  value="${2:-No value}"
  status="${3:-warning}"
  fallback="${4:-No fallback}"
  pretext="${5:-No pretext}"

  read -r -d '' json_string << EOM
{
   "attachments":[
      {
         "fallback": "${fallback}",
         "pretext": "${pretext}",
         "color": "${status}",
         "fields": [
            {
               "title": "${title}",
               "value": "${value}",
               "short": false
            }
         ]
      }
   ]
}
EOM

  curl -X POST "${SLACK_WEBHOOK_URL}" \
   -H 'Content-Type: application/json' \
   -d "${json_string}"

}