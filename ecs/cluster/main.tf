resource "aws_ecs_cluster" "this" {
  name = var.ecs_cluster.name.kebab_case

  setting {
    name  = "containerInsights"
    value = var.ecs_cluster.container_insights
  }

  dynamic "service_connect_defaults" {
    for_each = var.ecs_cluster.service_discovery.enable ? [0] : []
    content {
      namespace = var.ecs_cluster.service_discovery.namespace_arn
    }
  }

  tags = var.resource_tags
}

resource "aws_security_group" "this" {
  name = format(
    "%sECSClusterSecurityGroup",
    var.aws.account.name.camel_case
  )

  description = format(
    "Security group assigned to all services running in %s",
    var.ecs_cluster.name.kebab_case
  )

  vpc_id = data.aws_vpc.this.id
  tags = merge({
    Name = format(
      "%sECSClusterSecurityGroup",
      var.aws.account.name.camel_case
    )
  }, var.resource_tags)

  lifecycle {
    enabled = var.ecs_cluster.vpc.security_group.create
  }
}

resource "aws_security_group_rule" "allow_all" {
  count             = var.ecs_cluster.vpc.security_group.create ? 1 : 0
  description       = "Allow ECS services in the same ECS cluster to communicate with each other"
  type              = "ingress"
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.this.id
  to_port           = 0
  self              = true
}
