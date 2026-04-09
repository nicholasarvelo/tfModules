locals {
  load_balancer_name = format(
    "%s-%s",
    lookup(
      local.package.name_shorthand.kebabcase,
      var.ecs_service.name.kebab_case
    ),

    lookup(
      local.account.name_shorthand.lowercase,
      var.aws.account.name.snake_case
    )
  )

  target_groups_provided = (
    length(var.load_balancer.target_groups) > 0 ? true : false
  )
  aws_lb_target_group_configs = (
    local.target_groups_provided ?
    var.load_balancer.target_groups :
    [
      {
        name = format(
          "%s-%s-ipv4",
          lookup(
            local.package.name_shorthand.kebabcase,
            var.ecs_service.name.kebab_case
          ),
          lookup(
            local.account.name_shorthand.lowercase,
            var.aws.account.name.snake_case
          )
        )
        port            = var.task_definition.container_definitions[0].port_mappings[0].container_port
        protocol        = "HTTP"
        target_type     = "ip"
        ip_address_type = "ipv4"
        health_check = {
          healthy_threshold   = 2
          interval            = 45
          path                = "/healthcheck"
          port                = 56789
          timeout             = 5
          unhealthy_threshold = 2
        }
      }
    ]
  )
  aws_lb_target_groups = {
    for config in local.aws_lb_target_group_configs :
    config.ip_address_type => config
  }
}

# This resource creates an application load balancer for the ECS service being
# provisioned. Each ECS service has its own load balancer, which all traffic
# specific to the ECS service runs through.
resource "aws_lb" "this" {
  name               = local.load_balancer_name
  internal           = var.load_balancer.internal
  load_balancer_type = var.load_balancer.type
  ip_address_type    = var.load_balancer.ip_address_type
  security_groups    = [aws_security_group.load_balancer.id]
  subnets = (
    var.load_balancer.internal ?
    [for subnet in data.aws_subnet.private : subnet.id] :
    [for subnet in data.aws_subnet.public : subnet.id]
  )

  lifecycle {
    create_before_destroy = true
    enabled               = var.load_balancer.create
  }

  tags = var.resource_tags
}

resource "aws_lb_target_group" "this" {
  for_each        = var.load_balancer.create ? local.aws_lb_target_groups : {}
  name            = each.value.name
  port            = each.value.port
  protocol        = each.value.protocol
  target_type     = each.value.target_type
  ip_address_type = each.value.ip_address_type
  vpc_id          = data.aws_vpc.this.id

  health_check {
    healthy_threshold   = each.value.health_check.healthy_threshold
    interval            = each.value.health_check.interval
    path                = each.value.health_check.path
    port                = each.value.health_check.port
    timeout             = each.value.health_check.timeout
    unhealthy_threshold = each.value.health_check.unhealthy_threshold
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.resource_tags
}

# Creates an Application Load Balancer (ALB) listener for each defined
# port using HTTPS. Each listener is associated with a target group for
# forwarding traffic.
resource "aws_lb_listener" "https" {
  for_each = {
    for listener in var.load_balancer.listeners
    : format("%s_%s", listener.protocol, listener.port)
    => listener if listener.protocol == "HTTPS"
  }
  load_balancer_arn = aws_lb.this[0].arn
  port              = each.value.port
  protocol          = each.value.protocol
  certificate_arn   = each.value.certificate_arn

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.this["ipv4"].arn
      }
    }
  }
  tags = var.resource_tags
}

# Creates an Application Load Balancer (ALB) listener for each defined
# port using HTTP. Each listener is associated with a target group for
# forwarding traffic.
resource "aws_lb_listener" "http" {
  for_each = {
    for listener in var.load_balancer.listeners
    : format("%s_%s", listener.protocol, listener.port)
    => listener if listener.protocol == "HTTP"
  }
  load_balancer_arn = aws_lb.this[0].arn
  port              = each.value.port
  protocol          = each.value.protocol

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.this["ipv4"].arn
      }
    }
  }
  tags = var.resource_tags
}
