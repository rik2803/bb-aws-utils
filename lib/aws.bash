[[ -z ${LIB_COMMON_LOADED} ]] && { source ${LIB_DIR:-lib}/common.bash; }
export LIB_AWS_LOADED=1

check_envvar AWS_DEFAULT_REGION O eu-central-1

aws_update_service() {
  check_envvar AWS_DEFAULT_REGION R
  [[ -z ${1} || -z ${2} || -z ${3} || -z ${4} || -z ${5} ]] && \
    fail "aws_update_service aws_account_id aws_ecs_cluster_name aws_ecs_service_name aws_ecs_task_family_name image_tag"
  local aws_account_id=${1}
  local aws_ecs_cluster_name=${2}
  local aws_ecs_service_name=${3}
  local aws_ecs_task_family_name=${4}
  local image_tag=${5}

  info "Creating task definition file for ${aws_ecs_task_family_name} with version ${image_tag}"
  aws_ecs_create_task_definition_file "${aws_ecs_task_family_name}:${image_tag}"
  success "Task definition file successfully created"

  info "Registering task definition file for ${aws_ecs_task_family_name} with version ${image_tag}"
  aws_ecs_register_taskdefinition "${aws_ecs_task_family_name}"
  success "Task definition successfully registgered"

  info "Update service ${3} in cluster ${2} on AWS account ${1}"
  #aws ecs update-service --cluster ${aws_ecs_cluster_name} --force-new-deployment --service ${aws_ecs_service_name} --region ${AWS_REGION:-eu-central-1}
  aws ecs update-service --cluster ${aws_ecs_cluster_name} --force-new-deployment --service ${aws_ecs_service_name}
  success "Successfully updated service ${3} in cluster ${2} on AWS account ${1}"
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
  AWS_IMAGE=${1}

  aws ecs describe-task-definition --task-definition ${AWS_ECS_TASK_FAMILY} \
                                   --query 'taskDefinition' | \
                                   jq 'del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities)' | \
                                   jq '.containerDefinitions[0].image = "${AWS_IMAGE}"' > /taskdefinition.json
}

aws_ecs_register_taskdefinition() {
  # Limitation: only supports task definitions with 1 containerDefinition
  check_command aws || install_awscli
  check_command jq || install_sw jq
  check_envvar AWS_ECS_TASK_FAMILY R

  info "Registering a new task definition for ${AWS_ECS_TASK_FAMILY}"
  RESULT=$(aws ecs register-task-definition --family ${AWS_ECS_TASK_FAMILY} --cli-json file:///taskdefinition.json)
  NEW_TASK_DEFINITION_ARN=$(echo ${RESULT} | jq -r '.taskDefinition.taskDefinitionArn')
  success "Successfully registered new task definition for ${AWS_ECS_TASK_FAMILY}"
  info "New task definition ARN is ${NEW_TASK_DEFINITION_ARN}"
}
