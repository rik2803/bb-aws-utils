[[ -z ${LIB_COMMON_LOADED} ]] && { source ${LIB_DIR:-lib}/common.bash; }
export LIB_AWS_LOADED=1

check_envvar AWS_DEFAULT_REGION O eu-central-1

aws_update_service() {
  check_envvar AWS_DEFAULT_REGION R
  [[ -z ${1} || -z ${2} || -z ${3} || -z ${4} || -z ${5} || -z ${6} ]] && \
    fail "aws_update_service aws_ecs_cluster_name aws_ecs_service_name aws_ecs_task_family_name image_tag image_basename"
  local aws_ecs_cluster_name=${1}; shift
  local aws_ecs_service_name=${1}; shift
  local aws_ecs_task_family_name=${1}; shift
  local image_tag=${1}; shift
  local image_basename=${1}; shift

  info "Creating task definition file for ${aws_ecs_task_family_name} with version ${image_tag}"
  aws_ecs_create_task_definition_file "${image_basename}:${image_tag}"
  success "Task definition file successfully created"

  info "Registering task definition file for ${aws_ecs_task_family_name} with version ${image_tag}"
  aws_ecs_register_taskdefinition "${aws_ecs_task_family_name}"
  success "Task definition successfully registgered"

  info "Update service ${aws_ecs_service_name} in cluster ${aws_ecs_cluster_name}"
  aws ecs update-service --cluster ${aws_ecs_cluster_name} \
                         --task-definition ${AWS_ECS_NEW_TASK_DEFINITION_ARN} \
                         --force-new-deployment \
                         --service ${aws_ecs_service_name}
  success "Successfully updated service ${aws_ecs_service_name} in cluster ${aws_ecs_cluster_name}"
}


#######################################
# Create a task definition file based on
# the current task definition, replacing
# the image name with the new version
#
# Globals:
#
# Arguments:
#   Image Name: The name of the image, including tag
#
# Returns:
#   None
#######################################
aws_ecs_create_task_definition_file() {
  check_command aws || install_awscli
  check_command jq || install_sw jq
  check_envvar AWS_ECS_TASK_FAMILY R
  [[ -z ${1} ]] && fail "aws_ecs_create_task_definition_file docker_image"
  local aws_image=${1}; shift

  aws ecs describe-task-definition --task-definition ${AWS_ECS_TASK_FAMILY} \
                                   --query 'taskDefinition' | \
                                   jq "del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities)" | \
                                   jq ".containerDefinitions[0].image = \"${aws_image}\"" > /taskdefinition.json

  if is_debug_enabled; then
    debug "Content of task definition file -- START"
    cat /taskdefinition.json
    debug "Content of task definition file -- END"
  fi
}

aws_ecs_register_taskdefinition() {
  # Limitation: only supports task definitions with 1 containerDefinition
  check_command aws || install_awscli
  check_command jq || install_sw jq
  check_envvar AWS_ECS_TASK_FAMILY R

  info "Registering a new task definition for ${AWS_ECS_TASK_FAMILY}"
  RESULT=$(aws ecs register-task-definition --family ${AWS_ECS_TASK_FAMILY} --cli-input-json file:///taskdefinition.json)
  AWS_ECS_NEW_TASK_DEFINITION_ARN=$(echo ${RESULT} | jq -r '.taskDefinition.taskDefinitionArn')
  success "Successfully registered new task definition for ${AWS_ECS_TASK_FAMILY}"
  info "New task definition ARN is ${AWS_ECS_NEW_TASK_DEFINITION_ARN}"
}
