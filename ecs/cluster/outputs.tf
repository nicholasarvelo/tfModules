output "configuration" {
  value = {
    arn  = aws_ecs_cluster.this.arn
    id   = aws_ecs_cluster.this.id
    name = aws_ecs_cluster.this.name
    security_group = var.ecs_cluster.vpc.security_group.create ? {
      arn  = aws_security_group.this[0].arn
      id   = aws_security_group.this[0].id
      name = aws_security_group.this[0].name
      vpc  = aws_security_group.this[0].vpc_id
    } : {}
    service_discovery = var.ecs_cluster.service_discovery.enable
    setting           = aws_ecs_cluster.this.setting
  }
}
