# VPC Module

## Design Philosophy

This module operates on the principle that most VPCs follow predictable patterns. Rather than forcing you to calculate subnet CIDRs manually, it auto-provisions them by default. When you need precise control, you can disable auto-provisioning and specify exact CIDRs.

## How Auto-Provisioning Works

When you provide only a VPC CIDR block, the module automatically:

1. **Calculates /24 subnets** from your /16 CIDR using `cidrsubnet(vpc_cidr, 8, index)`
2. **Separates address space** - private subnets use indices 0-5, public subnets use indices 6-11
3. **Distributes across AZs** - cycles through available zones using the subnet index
4. **Creates NAT gateway** - places it in the first public subnet when both private and public subnets exist

This approach eliminates CIDR calculation errors and ensures consistent addressing across environments.

## Why Two Modes

**Auto-provision mode** (default) optimizes for speed and consistency. You get a production-ready VPC with properly segmented subnets without thinking about CIDR math.

**Manual mode** exists for scenarios where:
- You're integrating with existing networks that require specific CIDR blocks
- You need non-standard subnet sizes (not /24)
- You're migrating infrastructure and must preserve existing addressing

## Examples

### Auto-Provision (Default)

```hcl
inputs = {
  vpc = {
    assign_generated_ipv6_cidr_block = true
    enable_dns_hostnames             = true
    enable_dns_support               = true
    cidr_block                       = "172.16.0.0/16"
    name                             = "prod"
  }
}
```

**What happens:**
- Creates 6 private subnets: `172.16.0.0/24` through `172.16.5.0/24`
- Creates 6 public subnets: `172.16.6.0/24` through `172.16.11.0/24`
- Distributes subnets across all available AZs in the region
- Provisions NAT gateway in first public subnet
- Configures route tables automatically

### Manual Mode

```hcl
inputs = {
  vpc = {
    assign_generated_ipv6_cidr_block = true
    enable_dns_hostnames             = true
    enable_dns_support               = true
    cidr_block                       = "172.16.0.0/16"
    name                             = "prod"
    subnets = {
      auto_provision = {
        disable = true
      }
      private = [
        "172.16.16.0/20", "172.16.32.0/20",
        "172.16.48.0/20", "172.16.64.0/20",
        "172.16.80.0/20", "172.16.96.0/20"
      ]
      public = [
        "172.16.1.0/24", "172.16.2.0/24",
        "172.16.3.0/24", "172.16.4.0/24",
        "172.16.5.0/24", "172.16.6.0/24"
      ]
    }
  }
}
```

**What happens:**
- Uses your exact CIDR blocks instead of calculating them
- Still distributes across AZs based on list order
- Provisions NAT gateway in first public subnet
- Allows mixed subnet sizes (/20 private, /24 public)

## Why Single NAT Gateway

By default, this module creates one NAT gateway instead of one per AZ. This decision prioritizes cost over high availability because:

- NAT gateway costs are significant ($0.045/hour + data processing)
- Multi-AZ NAT gateways triple this cost
- Most workloads can tolerate brief internet outages during AZ failures
- You can override this by using `nat_gateway_config.subnet_index` to place additional gateways manually

For production workloads requiring HA, consider VPC endpoints instead of multiple NAT gateways.

## Why VPC Endpoints Matter

The module includes 17 pre-configured VPC endpoint options because:

- **Gateway endpoints** (S3, DynamoDB) are free and eliminate NAT gateway data charges
- **Interface endpoints** cost less than NAT gateway data processing for high-volume services
- Private connectivity improves security posture by keeping traffic off the internet

Enable endpoints selectively based on which AWS services your workload uses.

```hcl
inputs = {
  vpc = {
    cidr_block = "10.0.0.0/16"
    name       = "prod"
  }
  service_endpoints = {
    configure_gateway = {
      s3       = true
      dynamodb = true
    }
    configure_interface = {
      ecr_api    = true
      ecr_docker = true
      lambda     = true
      secrets_manager = true
    }
  }
}
```

## IPv6 Addressing Logic

When IPv6 is enabled, the module:

1. **Offsets private subnets** by 8 in the IPv6 space (configurable via `ipv6_config.private_subnet_offset`)
2. **Uses /4 prefix extension** by default (configurable via `ipv6_config.subnet_prefix_length`)
3. **Keeps public subnets at lower indices** to maintain logical separation

This prevents IPv6 address conflicts between public and private subnets while maintaining alignment with IPv4 addressing patterns.

## Configuration Variables

### Core Settings

- `vpc.cidr_block` - IPv4 CIDR for the VPC
- `vpc.name` - VPC name used in resource tags
- `vpc.subnets.auto_provision.disable` - Set to `true` for manual CIDR mode
- `vpc.subnets.private` - List of private subnet CIDRs (manual mode)
- `vpc.subnets.public` - List of public subnet CIDRs (manual mode)

### Advanced Settings

- `ipv6_config.private_subnet_offset` - IPv6 index offset for private subnets (default: 8)
- `ipv6_config.subnet_prefix_length` - IPv6 prefix bits to add (default: 4)
- `nat_gateway_config.subnet_index` - Which public subnet gets the NAT gateway (default: 0)
- `max_subnets_per_type` - Maximum subnets per type (default: 6)
- `service_endpoints.configure_gateway` - Enable S3/DynamoDB endpoints
- `service_endpoints.configure_interface` - Enable interface endpoints for AWS services
- `custom_service_endpoints` - Add custom VPC endpoint service names

## Outputs

- `vpc` - VPC ID, ARN, and name
- `private_subnets` - Map of private subnet details keyed by subnet name
- `public_subnets` - Map of public subnet details keyed by subnet name
- `availability_zones` - List of AZs used in the region
