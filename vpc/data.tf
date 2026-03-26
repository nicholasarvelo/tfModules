# Retrieves the current AWS account ID.
data "aws_caller_identity" "current" {}

# Retrieves the current AWS region.
data "aws_region" "current" {}

# Retrieves available Availability Zones in the current region.
data "aws_availability_zones" "this" {
  state = "available"
}

# Retrieves the S3 prefix list for use in security groups and route tables.
data "aws_prefix_list" "this" {
  name = format("com.amazonaws.%s.s3", data.aws_region.current.name)
}
