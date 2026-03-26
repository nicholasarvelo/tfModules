# Auto-provision private subnets by calculating /24 CIDR blocks from the VPC CIDR.
# Private subnets use indices 0 through (private_subnet_count - 1).
locals {
  auto_provisioned_private_subnets = [
    for i in range(var.vpc.subnets.auto_provision.private_subnet_count) :
    cidrsubnet(var.vpc.cidr_block, 8, i)
  ]

  auto_provisioned_public_subnets = [
    for i in range(var.vpc.subnets.auto_provision.public_subnet_count) :
    cidrsubnet(var.vpc.cidr_block, 8, i + var.vpc.subnets.auto_provision.private_subnet_count)
  ]

  private_subnet_list = (
    !var.vpc.subnets.auto_provision.disable
    ? local.auto_provisioned_private_subnets
    : var.vpc.subnets.private
  )

  public_subnet_list = (
    !var.vpc.subnets.auto_provision.disable
    ? local.auto_provisioned_public_subnets
    : var.vpc.subnets.public
  )

  private_cidr_block_map = {
    for index, cidr_block in local.private_subnet_list :
    cidr_block => {
      index      = index
      cidr_block = cidr_block
    }
  }

  public_cidr_block_map = {
    for index, cidr_block in local.public_subnet_list :
    cidr_block => {
      index      = index
      cidr_block = cidr_block
    }
  }

  private_availability_zone = {
    for key, value in local.private_cidr_block_map :
    key => element(data.aws_availability_zones.this.names, value.index)
  }

  public_availability_zone = {
    for key, value in local.public_cidr_block_map :
    key => element(data.aws_availability_zones.this.names, value.index)
  }

  aws_service_endpoints = {
    gateway = merge(
      {
        dynamodb = format("com.amazonaws.%s.dynamodb", data.aws_region.current.name)
        s3       = format("com.amazonaws.%s.s3", data.aws_region.current.name)
      },
      var.custom_service_endpoints.gateway
    )
    interface = merge(
      {
        cloudwatch_logs          = format("com.amazonaws.%s.logs", data.aws_region.current.name)
        dms                      = format("com.amazonaws.%s.dms", data.aws_region.current.name)
        ec2_messages             = format("com.amazonaws.%s.ec2messages", data.aws_region.current.name)
        ecr_api                  = format("com.amazonaws.%s.ecr.api", data.aws_region.current.name)
        ecr_docker               = format("com.amazonaws.%s.ecr.dkr", data.aws_region.current.name)
        firehose                 = format("com.amazonaws.%s.kinesis-firehose", data.aws_region.current.name)
        kms                      = format("com.amazonaws.%s.kms", data.aws_region.current.name)
        lambda                   = format("com.amazonaws.%s.lambda", data.aws_region.current.name)
        rds                      = format("com.amazonaws.%s.rds", data.aws_region.current.name)
        redshift                 = format("com.amazonaws.%s.redshift", data.aws_region.current.name)
        secrets_manager          = format("com.amazonaws.%s.secretsmanager", data.aws_region.current.name)
        sns                      = format("com.amazonaws.%s.sns", data.aws_region.current.name)
        sqs                      = format("com.amazonaws.%s.sqs", data.aws_region.current.name)
        systems_manager          = format("com.amazonaws.%s.ssm", data.aws_region.current.name)
        systems_manager_messages = format("com.amazonaws.%s.ssmmessages", data.aws_region.current.name)
      },
      var.custom_service_endpoints.interface
    )
  }
}

locals {
  is_private_cidr_list_empty = length(local.private_subnet_list) == 0
  is_public_cidr_list_empty  = length(local.public_subnet_list) == 0
  nat_requirements_met = (
    local.is_private_cidr_list_empty == false &&
    local.is_public_cidr_list_empty == false
  )
}

# Creates a Virtual Private Cloud with configurable IPv4 and optional IPv6 CIDR blocks.
# AWS automatically generates a default route table upon VPC creation.
resource "aws_vpc" "this" {
  cidr_block                       = var.vpc.cidr_block
  assign_generated_ipv6_cidr_block = var.vpc.assign_generated_ipv6_cidr_block
  enable_dns_support               = var.vpc.enable_dns_support
  enable_dns_hostnames             = var.vpc.enable_dns_hostnames

  tags = merge(
    {
      Name = var.vpc.name
    },
    var.resource_tags
  )
}

# Adopts the default route table automatically created by the VPC to apply custom tags.
resource "aws_default_route_table" "this" {
  default_route_table_id = aws_vpc.this.default_route_table_id

  tags = merge(
    {
      Name = format("%s-default-route-table", var.vpc.name)
    },
    var.resource_tags
  )

  depends_on = [aws_vpc.this]
}

# Creates private subnets distributed across availability zones with optional IPv6 support.
resource "aws_subnet" "private" {
  for_each   = local.private_cidr_block_map
  vpc_id     = aws_vpc.this.id
  cidr_block = local.private_cidr_block_map[each.key]["cidr_block"]
  ipv6_cidr_block = (
    var.vpc.assign_generated_ipv6_cidr_block ?
    cidrsubnet(
      aws_vpc.this.ipv6_cidr_block,
      var.ipv6_config.subnet_prefix_length,
      local.private_cidr_block_map[each.key]["index"] + var.ipv6_config.private_subnet_offset
    )
    : null
  )
  availability_zone = local.private_availability_zone[each.key]

  tags = merge(
    {
      Name = (
        format(
          "%s-private-%s",
          var.vpc.name,
          local.private_availability_zone[each.key]
        )
      )
      Type = "Private"
    },
    var.resource_tags
  )
}

# Creates an Elastic IP address for the NAT gateway.
resource "aws_eip" "this" {
  count  = local.nat_requirements_met ? 1 : 0
  domain = "vpc"

  tags = merge(
    {
      Name = format("%s-nat-gateway-elastic-ip", var.vpc.name)
    },
    var.resource_tags
  )
}

# Creates a NAT gateway to enable private subnet instances to access the internet
# while preventing inbound connections from the internet.
resource "aws_nat_gateway" "this" {
  count         = local.nat_requirements_met ? 1 : 0
  allocation_id = aws_eip.this[0].id
  subnet_id     = aws_subnet.public[local.public_subnet_list[var.nat_gateway_config.subnet_index]].id

  tags = merge(
    {
      Name = (
        format(
          "%s-nat-public-%s",
          var.vpc.name,
          aws_subnet.public[local.public_subnet_list[var.nat_gateway_config.subnet_index]].availability_zone
        )
      )
    },
    var.resource_tags
  )

  depends_on = [aws_internet_gateway.this]
}

# Creates route tables for private subnets with routes to the NAT gateway for internet access.
resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id

  dynamic "route" {
    for_each = aws_nat_gateway.this
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[0].id
    }
  }
  dynamic "route" {
    for_each = var.vpc.routes.private
    content {
      cidr_block                 = route.value.cidr_block
      destination_prefix_list_id = route.value.destination_prefix_list_id
      ipv6_cidr_block            = route.value.ipv6_cidr_block
      carrier_gateway_id         = route.value.carrier_gateway_id
      core_network_arn           = route.value.core_network_arn
      egress_only_gateway_id     = route.value.egress_only_gateway_id
      gateway_id                 = route.value.gateway_id
      local_gateway_id           = route.value.local_gateway_id
      nat_gateway_id             = route.value.nat_gateway_id
      network_interface_id       = route.value.network_interface_id
      transit_gateway_id         = route.value.transit_gateway_id
      vpc_endpoint_id            = route.value.vpc_endpoint_id
      vpc_peering_connection_id  = route.value.vpc_peering_connection_id
    }
  }

  tags = merge(
    {
      Name = format("%s", aws_subnet.private[each.key].tags.Name)
    },
    var.resource_tags
  )
}

# Associates each private subnet with its corresponding route table.
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

# Creates VPC gateway endpoints for AWS services to reduce NAT gateway costs
# by routing traffic through AWS's private network.
resource "aws_vpc_endpoint" "gateway" {
  for_each = toset([
    for endpoint, create in var.service_endpoints.configure_gateway
    : endpoint if create == true && local.is_private_cidr_list_empty == false
  ])
  service_name      = local.aws_service_endpoints.gateway[each.key]
  vpc_endpoint_type = "Gateway"
  vpc_id            = aws_vpc.this.id

  tags = merge(
    {
      Name = format(
        "%s-%s-vpc-endpoint-gateway",
        var.vpc.name,
        replace(each.key, "_", "-")
      )
    },
    var.resource_tags
  )
}

# Creates VPC interface endpoints for AWS services to enable private connectivity
# without requiring internet gateway or NAT gateway.
resource "aws_vpc_endpoint" "interface" {
  for_each = toset([
    for endpoint, create in var.service_endpoints.configure_interface
    : endpoint if create == true && local.is_private_cidr_list_empty == false
  ])
  service_name      = local.aws_service_endpoints.interface[each.key]
  vpc_endpoint_type = "Interface"
  vpc_id            = aws_vpc.this.id

  tags = merge(
    {
      Name = format(
        "%s-%s-vpc-endpoint-interface",
        var.vpc.name,
        replace(each.key, "_", "-")
      )
    },
    var.resource_tags
  )
}

# Prepares mappings for associating gateway endpoints with private route tables.
locals {
  endpoint_gateways = {
    for endpoint_gateway in aws_vpc_endpoint.gateway
    : endpoint_gateway.tags["Name"]
    => endpoint_gateway
  }

  private_route_tables = {
    for private_route_table in aws_route_table.private
    : private_route_table.tags["Name"]
    => private_route_table
  }

  vpc_gateway_private_route_mappings = [
    for endpoint_gateway in local.endpoint_gateways : {
      for private_route_table in local.private_route_tables :
      format(
        "%s_%s",
        endpoint_gateway.tags["Name"],
        private_route_table.tags["Name"]
        ) => {
        private_route_table_id = private_route_table.id
        gateway_endpoint_id    = endpoint_gateway.id
      }
    }
  ]

  private_gateway_route_associations = merge(
    local.vpc_gateway_private_route_mappings...
  )

  endpoint_interfaces = {
    for vpc_interface in aws_vpc_endpoint.interface
    : vpc_interface.tags["Name"]
    => vpc_interface
  }

  private_subnets = {
    for private_subnet in aws_subnet.private
    : private_subnet.tags["Name"]
    => private_subnet
  }

  vpc_interface_private_subnet_mappings = [
    for vpc_interface in local.endpoint_interfaces : {
      for private_subnet in local.private_subnets :
      format(
        "%s_%s",
        vpc_interface.tags["Name"],
        private_subnet.tags["Name"]
        ) => {
        private_subnet_id = private_subnet.id
        vpc_endpoint_id   = vpc_interface.id
      }
    }
  ]

  vpc_interface_private_subnet_associations = merge(
    local.vpc_interface_private_subnet_mappings...
  )
}

# Associates gateway endpoints with private route tables to enable private AWS service access.
resource "aws_vpc_endpoint_route_table_association" "private" {
  for_each        = local.private_gateway_route_associations
  route_table_id  = each.value["private_route_table_id"]
  vpc_endpoint_id = each.value["gateway_endpoint_id"]
}

# Associates interface endpoints with private subnets to enable private AWS service access.
resource "aws_vpc_endpoint_subnet_association" "private" {
  for_each        = local.vpc_interface_private_subnet_associations
  subnet_id       = each.value["private_subnet_id"]
  vpc_endpoint_id = each.value["vpc_endpoint_id"]
}

# Creates public subnets distributed across availability zones with optional IPv6 support.
resource "aws_subnet" "public" {
  for_each = {
    for cidr in local.public_cidr_block_map : cidr["cidr_block"] => cidr
  }
  vpc_id     = aws_vpc.this.id
  cidr_block = local.public_cidr_block_map[each.key]["cidr_block"]
  ipv6_cidr_block = (
    var.vpc.assign_generated_ipv6_cidr_block ?
    cidrsubnet(
      aws_vpc.this.ipv6_cidr_block,
      var.ipv6_config.subnet_prefix_length,
      local.public_cidr_block_map[each.key]["index"]
    )
    : null
  )

  availability_zone = local.public_availability_zone[each.key]

  tags = merge(
    {
      Name = (
        format(
          "%s-public-%s",
          var.vpc.name,
          local.public_availability_zone[each.key]
        )
      )
      Type = "Public"
    },
    var.resource_tags
  )
}

# Creates an internet gateway to enable public subnet instances to communicate with the internet.
resource "aws_internet_gateway" "this" {
  count  = local.is_public_cidr_list_empty ? 0 : 1
  vpc_id = aws_vpc.this.id

  tags = merge(
    {
      Name = format("%s-internet-gateway", var.vpc.name)
    },
    var.resource_tags
  )
}

# Creates a route table for public subnets with a default route to the internet gateway.
resource "aws_route_table" "public" {
  count  = local.is_public_cidr_list_empty ? 0 : 1
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  dynamic "route" {
    for_each = var.vpc.routes.public
    content {
      cidr_block                 = route.value.cidr_block
      destination_prefix_list_id = route.value.destination_prefix_list_id
      ipv6_cidr_block            = route.value.ipv6_cidr_block
      carrier_gateway_id         = route.value.carrier_gateway_id
      core_network_arn           = route.value.core_network_arn
      egress_only_gateway_id     = route.value.egress_only_gateway_id
      gateway_id                 = route.value.gateway_id
      local_gateway_id           = route.value.local_gateway_id
      nat_gateway_id             = route.value.nat_gateway_id
      network_interface_id       = route.value.network_interface_id
      transit_gateway_id         = route.value.transit_gateway_id
      vpc_endpoint_id            = route.value.vpc_endpoint_id
      vpc_peering_connection_id  = route.value.vpc_peering_connection_id
    }
  }

  tags = merge(
    {
      Name = format("%s-public-route-table", var.vpc.name)
    },
    var.resource_tags
  )
}

# Associates each public subnet with the public route table.
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[0].id
}
