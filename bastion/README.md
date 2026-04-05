# Bastion Host Module

This module provisions a bastion host behind a load balancer with DNS, eliminating direct public IP exposure. By default it uses Amazon Linux 2023, a Network Load Balancer, and SSH on port 22. A random subnet is selected automatically so you don't need to specify placement — the module handles it deterministically after the first apply.

## What Gets Created

When you provision a bastion, the module automatically:

1. **Launches an EC2 instance** with an encrypted root volume in a randomly selected subnet
2. **Creates an IAM role and instance profile** for the EC2 instance with your specified managed policies
3. **Provisions a load balancer** (NLB by default) across all matching subnets
4. **Creates a target group** routing traffic on port 22 to the instance
5. **Creates a Route53 alias record** pointing the hostname to the load balancer
6. **Creates a security group** allowing health checks from within the VPC and all outbound traffic

## Examples

### Internet-Facing Bastion (Default)

```hcl
inputs = {
  ami_architecture            = "arm64"
  aws_region                  = "us-east-1"
  aws_account_name            = "production"
  hostname                    = "bastion"
  instance_type               = "t4g.micro"
  import_key_pair             = false
  key_pair                    = { key_name = "my-key" }
  iam_role_managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  route53_zone_name           = "example.com"
  vpc_name                    = "prod"
}
```

**What happens:**
- Launches an AL2023 ARM instance in a random public subnet
- Creates an internet-facing NLB with a TCP listener on port 22
- Creates `bastion.example.com` as an alias to the NLB
- Uses an existing key pair stored in AWS

### Internal Bastion

```hcl
inputs = {
  ami_architecture            = "x86_64"
  aws_region                  = "us-east-1"
  aws_account_name            = "production"
  hostname                    = "internal-bastion"
  instance_type               = "t3.micro"
  import_key_pair             = true
  key_pair                    = { key_name = "my-key", public_key = "ssh-ed25519 AAAA..." }
  iam_role_managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  load_balancer_scheme        = "internal"
  route53_zone_name           = "internal.example.com"
  vpc_name                    = "prod"
}
```

**What happens:**
- Places the instance in a private subnet
- Creates an internal NLB accessible only from within the VPC
- Imports the provided SSH public key as an AWS key pair

## Why a Load Balancer Instead of a Public IP

Using a load balancer provides:

- **Stable DNS** — the hostname never changes even if the instance is replaced
- **Health checks** — the NLB monitors the bastion and stops routing to unhealthy targets
- **Subnet flexibility** — the NLB spans all matching subnets without pinning the instance to one

The trade-off is additional NLB cost, but for a bastion this is minimal and the operational benefits outweigh it.

## Why Random Subnet Selection

The module uses `random_integer` keyed on `aws_region` to pick a subnet. This means:

- The subnet choice is stable across applies (no instance recreation)
- It only changes if the region changes
- You don't need to decide which subnet to use

## Configuration Variables

### Required

- `ami_architecture` - `"arm64"` or `"x86_64"`
- `aws_region` - AWS region for deployment
- `aws_account_name` - AWS account name
- `hostname` - Bastion hostname (lowercase alphanumeric and hyphens only)
- `instance_type` - EC2 instance type
- `import_key_pair` - `true` to import a new key pair, `false` to use an existing one
- `key_pair` - Map with `key_name` (and `public_key` if importing)
- `iam_role_managed_policy_arns` - List of IAM policy ARNs for the instance role
- `route53_zone_name` - Route53 hosted zone for the DNS record
- `vpc_name` - VPC name tag to deploy into

### Optional

- `ami_id` - Override the default AL2023 AMI (default: latest AL2023)
- `ami_name_filter` - AMI name filter (default: `["al2023-ami-2023.*"]`)
- `ami_owner` - AMI owner account ID (default: `["137112412989"]` — AWS)
- `function` - Resource function tag (default: `"Bastion Host"`)
- `instance_type` - EC2 instance class
- `load_balancer_scheme` - `"internet-facing"` (default) or `"internal"`
- `load_balancer_type` - `"network"` (default), `"application"`, or `"none"`
- `load_balancer_listener_port` - Listener port (default: `22`)
- `load_balancer_listener_protocol` - Listener protocol (default: `"TCP"`)
- `target_group_port` - Target port (default: `22`)
- `target_group_protocol` - Target protocol (default: `"TCP"`)
- `root_volume_size` - Root EBS volume size in GiB (default: `8`)
- `root_volume_type` - Root EBS volume type (default: `"gp3"`)
- `root_volume_iops` - Root EBS volume IOPS (default: `3000`)

## Outputs

- `bastion_security_group_id` - Security group ID (use to add custom ingress rules in the root module)
- `bastion_urls` - List of FQDNs for the bastion
- `bastion_instance_id` - EC2 instance ID
