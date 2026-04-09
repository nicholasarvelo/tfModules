output "configuration" {
  value = {
    ecs_service = {
      arn                                = try(aws_ecs_service.this.arn, null)
      name                               = try(aws_ecs_service.this.name, null)
      load_balancer                      = try(aws_ecs_service.this.load_balancer, null)
      id                                 = try(aws_ecs_service.this.id, null)
      wait_for_steady_state              = try(aws_ecs_service.this.wait_for_steady_state, null)
      availability_zone_rebalancing      = try(aws_ecs_service.this.availability_zone_rebalancing, null)
      capacity_provider_strategy         = try(aws_ecs_service.this.capacity_provider_strategy, null)
      cluster                            = try(aws_ecs_service.this.cluster, null)
      deployment_circuit_breaker         = try(aws_ecs_service.this.deployment_circuit_breaker, null)
      deployment_configuration           = try(aws_ecs_service.this.deployment_configuration, null)
      deployment_maximum_percent         = try(aws_ecs_service.this.deployment_maximum_percent, null)
      deployment_minimum_healthy_percent = try(aws_ecs_service.this.deployment_minimum_healthy_percent, null)
      desired_count                      = try(aws_ecs_service.this.desired_count, null)
      enable_execute_command             = try(aws_ecs_service.this.enable_execute_command, null)
    }

    ecs_task_role = {
      arn                = try(aws_iam_role.ecs_task.arn, null)
      name               = try(aws_iam_role.ecs_task.name, null)
      description        = try(aws_iam_role.ecs_task.description, null)
      id                 = try(aws_iam_role.ecs_task.id, null)
      assume_role_policy = try(jsondecode(aws_iam_role.ecs_task.assume_role_policy), null)
    }

    ecs_task_execution_role = {
      arn                = try(aws_iam_role.ecs_task_execution.arn, null)
      name               = try(aws_iam_role.ecs_task_execution.name, null)
      description        = try(aws_iam_role.ecs_task_execution.description, null)
      id                 = try(aws_iam_role.ecs_task_execution.id, null)
      assume_role_policy = try(jsondecode(aws_iam_role.ecs_task_execution.assume_role_policy), null)
    }
  }
}
