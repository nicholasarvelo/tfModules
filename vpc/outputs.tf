output "configuration" {
  value = {
    arn                = aws_vpc.this.arn
    availability_zones = data.aws_availability_zones.this.names
    id                 = aws_vpc.this.id
    name               = aws_vpc.this.tags.Name
    subnet = {
      private = { for subnet in aws_subnet.private : subnet.tags.Name => {
        arn             = subnet.arn
        id              = subnet.id
        ipv4_cidr_block = subnet.cidr_block
        ipv6_cidr_block = subnet.ipv6_cidr_block
        vpc_id          = subnet.vpc_id
        }
      }
      public = { for subnet in aws_subnet.public : subnet.tags.Name => {
        arn             = subnet.arn
        id              = subnet.id
        ipv4_cidr_block = subnet.cidr_block
        ipv6_cidr_block = subnet.ipv6_cidr_block
        vpc_id          = subnet.vpc_id
        }
      }
    }
  }
}
