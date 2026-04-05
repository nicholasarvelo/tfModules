# ECS Cluster Module

## Design Philosophy

This module creates an ECS cluster with sensible defaults for production workloads. Container Insights is enabled by default, and a shared security group is automatically created to allow intra-cluster communication. Service Connect integration is opt-in via Cloud Map namespace configuration.

## What Gets Created

When you provision a cluster, the module automatically:

1. **Creates the ECS cluster** with Container Insights enabled
2. **Creates a shared security group** scoped to the cluster's VPC with a self-referencing ingress rule
3. **Configures Service Connect** when a Cloud Map namespace is provided

The shared security group allows all services within the cluster to communicate freely with each other, eliminating the need to manage per-service ingress rules for internal traffic.

## Examples

### Basic Cluster

```hcl
inputs = {
  ecs_cluster = {
    name = {
      kebab_case = "prod-api"
    }
    service_discovery = {
      enable        = false
      namespace_arn = ""
    }
    vpc = {
      id   = "vpc-abc123"
      name = "prod"
    }
  }
}
```

**What happens:**
- Creates an ECS cluster named `prod-api`
- Enables Container Insights
- Creates a shared security group in the specified VPC
- Adds a self-referencing ingress rule for intra-cluster communication

### With Service Connect

```hcl
inputs = {
  ecs_cluster = {
    name = {
      kebab_case = "prod-api"
    }
    service_discovery = {
      enable        = true
      namespace_arn = "arn:aws:servicediscovery:us-east-1:123456789012:namespace/ns-abc123"
    }
    vpc = {
      id   = "vpc-abc123"
      name = "prod"
    }
  }
}
```

**What happens:**
- Creates the cluster with Service Connect defaults pointing to the Cloud Map namespace
- Services in this cluster can use Service Connect for service-to-service communication

### Without Shared Security Group

```hcl
inputs = {
  ecs_cluster = {
    name = {
      kebab_case = "prod-api"
    }
    service_discovery = {
      enable        = false
      namespace_arn = ""
    }
    vpc = {
      id   = "vpc-abc123"
      name = "prod"
      security_group = {
        create = false
      }
    }
  }
}
```

**What happens:**
- Creates the cluster without a shared security group
- You manage security groups per-service instead

## Why a Shared Security Group

The module creates a cluster-wide security group with a self-referencing ingress rule by default. This means any service assigned this security group can reach any other service in the cluster on any port. This simplifies networking for microservice architectures where services need to communicate freely.

Disable this when you need strict per-service network isolation.

## Why Container Insights Is Enabled

Container Insights provides cluster, service, and task-level metrics out of the box. The cost is minimal compared to the operational visibility it provides. Set `container_insights` to `"disabled"` if you're optimizing for cost in non-production environments.

## Configuration Variables

### Core Settings

- `ecs_cluster.name` - Cluster name as a map with `kebab_case` key
- `ecs_cluster.container_insights` - `"enhanced"`, `"enabled"` (default), or `"disabled"`
- `ecs_cluster.vpc.id` - VPC ID for the shared security group
- `ecs_cluster.vpc.name` - VPC name tag for lookup
- `ecs_cluster.vpc.security_group.create` - Create shared security group (default: `true`)

### Service Discovery

- `ecs_cluster.service_discovery.enable` - Enable Service Connect defaults
- `ecs_cluster.service_discovery.namespace_arn` - Cloud Map namespace ARN

### Other

- `aws` - Hosting AWS account and region metadata
- `resource_tags` - Map of tags applied to all resources

## Outputs

- `configuration.arn` - Cluster ARN
- `configuration.id` - Cluster ID
- `configuration.name` - Cluster name
- `configuration.security_group` - Shared security group details (ARN, ID, name, VPC)
- `configuration.service_discovery` - Whether Service Connect is enabled
- `configuration.setting` - Cluster settings
