locals {
  load_balancer_security_group_name = format(
    "%s-%s-ecs-service-load-balancer",
    var.ecs_service.name.kebab_case,
    var.aws.account.name.snake_case
  )

  load_balancer_security_group_egress_rules = concat(
    var.load_balancer.security_group_rules.egress,
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

  load_balancer_security_group_ingress_rules = concat(
    var.load_balancer.security_group_rules.ingress,
    [
      {
        description                  = "Allow HTTPS IPv4 traffic"
        cidr_ipv4                    = "0.0.0.0/0"
        cidr_ipv6                    = null
        ip_protocol                  = "tcp"
        from_port                    = 443
        to_port                      = 443
        referenced_security_group_id = null
      },
      {
        description                  = "Allow HTTPS IPv6 traffic"
        cidr_ipv4                    = null
        cidr_ipv6                    = "::/0"
        ip_protocol                  = "tcp"
        from_port                    = 443
        to_port                      = 443
        referenced_security_group_id = null
      }
    ]
  )

  load_balancer_egress_rules = {
    for rule in local.load_balancer_security_group_egress_rules
    : replace(title(rule.description), " ", "") => rule
  }

  load_balancer_ingress_rules = {
    for rule in local.load_balancer_security_group_ingress_rules
    : replace(title(rule.description), " ", "") => rule
  }
}

# Creates a security group for the ECS service load balancer. This security
# group acts as a firewall, controlling the traffic allowed to and from the
# load balancer
resource "aws_security_group" "load_balancer" {
  name   = local.load_balancer_security_group_name
  vpc_id = data.aws_vpc.this.id

  lifecycle {
    create_before_destroy = true
    enabled               = var.load_balancer.create
  }

  tags = merge(
    var.resource_tags,
    {
      Name = local.load_balancer_security_group_name
    }
  )
}

resource "aws_vpc_security_group_egress_rule" "load_balancer" {
  for_each = var.load_balancer.create ? local.load_balancer_egress_rules : {}

  description                  = each.value.description
  security_group_id            = aws_security_group.load_balancer.id
  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  ip_protocol                  = each.value.ip_protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  referenced_security_group_id = each.value.referenced_security_group_id

  tags = var.resource_tags
}

resource "aws_vpc_security_group_ingress_rule" "load_balancer" {
  for_each = var.load_balancer.create ? local.load_balancer_ingress_rules : {}

  description                  = each.value.description
  security_group_id            = aws_security_group.load_balancer.id
  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  ip_protocol                  = each.value.ip_protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  referenced_security_group_id = each.value.referenced_security_group_id

  tags = var.resource_tags
}
