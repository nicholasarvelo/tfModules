resource "aws_ecs_service" "this" {
  availability_zone_rebalancing      = var.ecs_service.availability_zone_rebalancing
  name                               = var.ecs_service.name.kebab_case
  cluster                            = data.aws_ecs_cluster.this.id
  launch_type                        = var.ecs_service.launch_type
  platform_version                   = var.ecs_service.platform_version
  desired_count                      = var.ecs_service.desired_count
  deployment_maximum_percent         = var.ecs_service.deployment.maximum_percent
  deployment_minimum_healthy_percent = var.ecs_service.deployment.minimum_percent
  enable_execute_command             = var.ecs_service.deployment.execute_command.enable
  task_definition                    = aws_ecs_task_definition.this.arn
  health_check_grace_period_seconds  = var.ecs_service.health_check.grace_period

  deployment_configuration {
    bake_time_in_minutes = var.ecs_service.deployment.configuration.bake_time_in_minutes
    strategy             = var.ecs_service.deployment.configuration.strategy

    dynamic "canary_configuration" {
      for_each = var.ecs_service.deployment.configuration.canary_configuration.enable ? [0] : []
      content {
        canary_bake_time_in_minutes = var.ecs_service.deployment.configuration.canary_configuration.canary_bake_time_in_minutes
        canary_percent              = var.ecs_service.deployment.configuration.canary_configuration.canary_percentage
      }
    }

    dynamic "linear_configuration" {
      for_each = var.ecs_service.deployment.configuration.linear_configuration.enable ? [0] : []
      content {
        step_bake_time_in_minutes = var.ecs_service.deployment.configuration.linear_configuration.step_bake_time_in_minutes
        step_percent              = var.ecs_service.deployment.configuration.linear_configuration.step_percent
      }
    }
  }

  deployment_circuit_breaker {
    enable   = var.ecs_service.deployment.circuit_breaker.enable
    rollback = var.ecs_service.deployment.circuit_breaker.rollback
  }

  network_configuration {
    subnets         = [for subnet in data.aws_subnet.private : subnet.id]
    security_groups = local.ecs_security_group_list
  }

  dynamic "load_balancer" {
    for_each = {
      for target_group in aws_lb_target_group.this :
      target_group.name => target_group
    }

    content {
      target_group_arn = load_balancer.value.arn
      container_name   = var.ecs_service.name.kebab_case
      container_port   = var.task_definition.container_definitions[0].port_mappings[0].container_port
    }
  }

  dynamic "service_connect_configuration" {
    for_each = var.ecs_service.service_connect.enable ? [0] : []
    content {
      enabled   = var.ecs_service.service_connect.enable
      namespace = var.ecs_service.service_connect.namespace_arn

      dynamic "log_configuration" {
        for_each = var.ecs_service.service_connect.log_configuration.enable ? [0] : []
        content {
          log_driver = var.ecs_service.service_connect.log_configuration.log_driver
          options    = var.ecs_service.service_connect.log_configuration.options

          secret_option {
            name = "apiKey"
            value_from = format(
              "arn:aws:ssm:%s:%s:parameter/%s/%s/DATADOG_API_KEY",
              var.aws.region.kebab_case,
              var.aws.account.id,
              var.ecs_service.name.kebab_case,
              var.aws.account.name.kebab_case
            )
          }
        }
      }

      dynamic "service" {
        for_each = var.ecs_service.service_connect.service
        content {
          port_name      = service.value.port_name
          discovery_name = service.value.discovery_name

          client_alias {
            port     = service.value.client_alias.port
            dns_name = service.value.client_alias.dns_name
          }
        }
      }
    }
  }

  tags = var.resource_tags

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener.https
  ]
}
