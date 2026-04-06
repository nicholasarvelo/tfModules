data "aws_vpc" "this" {
  id = var.ecs_cluster.vpc.id
  tags = {
    Name = var.ecs_cluster.vpc.name
  }
}
