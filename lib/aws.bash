[[ -z ${LIB_COMMON_LOADED} ]] && { source ${LIB_DIR:-lib}/common.bash; }
export LIB_AWS_LOADED=1

aws_update_service() {
  [[ -z ${1} || -z ${2} || -z ${3} ]] && fail "aws_update_service aws_account_id aws_ecs_cluster_name aws_ecs_service_name"
  local aws_account_id=${1}
  local aws_ecs_cluster_name=${2}
  local aws_ecs_service_name=${3}

  info "Update service ${3} in cluster ${2} on AWS account ${1}"
  success "Successfully updated service ${3} in cluster ${2} on AWS account ${1}"
}

aws_ecs_register_taskdefinition() {
  # Limitation: only supports task definitions with 1 containerDefinition
  check_command aws || install_awscli
  check_command jq
  check_envvar AWS_ECS_TASKFAMILY R

  info "Registering a new task definition for ${AWS_ECS_TASKFAMILY}"
  success "Successfully registered new task definition for ${AWS_ECS_TASKFAMILY}"
}
