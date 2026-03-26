# Retrieves the current AWS account ID.
data "aws_caller_identity" "current" {}

# Retrieves the current AWS region.
data "aws_region" "current" {}

# Retrieves available Availability Zones in the current region.
data "aws_availability_zones" "this" {
  state = "available"
}
