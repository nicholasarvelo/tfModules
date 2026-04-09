# Retrieves the AWS account ID for the current session.
data "aws_caller_identity" "this" {}

# Retrieves ECR repository information for the container image.
data "aws_ecr_repository" "this" {
  name        = var.task_definition.ecr_repo.name
  registry_id = var.task_definition.ecr_repo.id
}

# Retrieves ECS cluster information.
data "aws_ecs_cluster" "this" {
  cluster_name = var.ecs_service.cluster
}

# Retrieves the AWS region for the current session.
data "aws_region" "this" {}


# Loops through the list of subnets creating an instance of this data source
# for each subnet. This is used to populate a list of subnets to associate
# with the ECS service.
data "aws_subnet" "private" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

# Loops through the list of public subnets creating an instance of this data
# source for each subnet. This is used to populate a list of subnets to
# associate with the ECS service.
data "aws_subnet" "public" {
  for_each = toset(data.aws_subnets.public.ids)
  id       = each.value
}

# Generates a list of all subnets associated to the specific VPC ID. The list
# is then further filtered to only list subnets whose "name" contains "private".
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  tags = {
    Name = "*-private*"
  }
}

# Generates a list of all subnets associated to the specific VPC ID. The list
# is then further filtered to only list subnets whose "name" contains "-public".
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  tags = {
    Name = "*-public*"
  }
}

# Retrieves VPC information.
data "aws_vpc" "this" {
  tags = {
    Name = var.vpc_name
  }
}
