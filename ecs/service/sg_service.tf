locals {
  ecs_service_security_group_name = format(
    "%s-%s-ecs-service",
    var.ecs_service.name.kebab_case,
    var.aws.account.name.snake_case
  )

  ecs_service_security_group_egress_rules = concat(
    var.ecs_service.security_group_rules.egress,
    [
      {
        description                  = "Allow all outbound IPv4 traffic"
        cidr_ipv4                    = "0.0.0.0/0"
        cidr_ipv6                    = null
        ip_protocol                  = "-1"
        from_port                    = null
        to_port                      = null
        referenced_security_group_id = null
      },
      {
        description                  = "Allow all outbound IPv6 traffic"
        cidr_ipv4                    = null
        cidr_ipv6                    = "::/0"
        ip_protocol                  = "-1"
        from_port                    = null
        to_port                      = null
        referenced_security_group_id = null
      }
    ]
  )

  ecs_service_security_group_ingress_rules = concat(
    var.ecs_service.security_group_rules.ingress,
    var.load_balancer.create ? [
      {
        description                  = "Allow inbound traffic from load balancer"
        cidr_ipv4                    = null
        cidr_ipv6                    = null
        ip_protocol                  = "-1"
        from_port                    = null
        to_port                      = null
        referenced_security_group_id = aws_security_group.load_balancer.id
      }
    ] : []
  )

  ecs_service_egress_rules = {
    for rule in local.ecs_service_security_group_egress_rules
    : replace(title(rule.description), " ", "") => rule
  }

  ecs_service_ingress_rules = {
    for rule in local.ecs_service_security_group_ingress_rules
    : replace(title(rule.description), " ", "") => rule
  }

  ecs_security_group_list = concat(
    [aws_security_group.ecs_service.id],
    var.ecs_service.additional_security_group_ids
  )
}

# Creates a security group for the ECS service.This security group acts as a
# firewall, controlling the traffic allowed to and from the ECS service.
resource "aws_security_group" "ecs_service" {
  name   = local.ecs_service_security_group_name
  vpc_id = data.aws_vpc.this.id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.resource_tags,
    {
      Name = local.ecs_service_security_group_name
    }
  )
}

resource "aws_vpc_security_group_egress_rule" "ecs_service" {
  for_each = local.ecs_service_egress_rules

  description                  = each.value.description
  security_group_id            = aws_security_group.ecs_service.id
  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  ip_protocol                  = each.value.ip_protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  referenced_security_group_id = each.value.referenced_security_group_id

  tags = var.resource_tags
}

resource "aws_vpc_security_group_ingress_rule" "ecs_service" {
  for_each = local.ecs_service_ingress_rules

  description                  = each.value.description
  security_group_id            = aws_security_group.ecs_service.id
  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  ip_protocol                  = each.value.ip_protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  referenced_security_group_id = each.value.referenced_security_group_id

  tags = var.resource_tags
}
