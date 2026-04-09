# ECS Service Module

This module provisions a complete ECS service with its task definition, IAM roles, security groups, optional load balancer, and autoscaling. It supports both Fargate and EC2 launch types through a unified `task_definition` variable. Although an assumption that I will probably need to revisit and refactor in the future, currently the module enforces the use of Datadog and Fluent Bit sidecars for observability, so all task definitions include these containers by default.

## What Gets Created

When you provision a service, the module automatically:

1. **Creates the ECS service** with deployment configuration, circuit breaker, and network settings
2. **Registers a task definition** with your application container plus Datadog and Fluent Bit sidecars
3. **Creates two IAM roles** — a task role (for your app) and a task execution role (for ECS agent operations)
4. **Creates a security group** for the service with configurable ingress/egress rules
5. **Provisions a CloudWatch log group** for sidecar container logs
6. **Configures autoscaling** with a target and optional scheduled scale-in/scale-out actions
7. **Creates a load balancer** (optional) with security group, target groups, and listeners

## Examples

### Minimal Fargate Service

```hcl
inputs = {
  ecs_service = {
    cluster = "prod-api"
    name = {
      kebab_case = "my-service"
      snake_case = "my_service"
    }
    security_group_rules = {
      ingress = []
      egress  = []
    }
  }

  task_definition = {
    family = "my-service"
    cpu    = "1024"
    memory = "2048"

    ecr_repo = {
      name = "my-service"
      id   = "123456789012"
    }
    ecr_image_tag = "v1.0.0"

    iam = {
      permissions_boundary = {
        name   = "MyServiceBoundary"
        path   = "/"
        policy = { Version = "2012-10-17", Statement = [] }
      }
      task_role          = {}
      task_execution_role = {}
    }

    cloudwatch_log_group = {
      name = "/my-service/prod"
    }

    container_definitions = [
      {
        name  = "my-service"
        image = ""
        port_mappings = [
          {
            container_port = 8080
            name           = "http"
            protocol       = "tcp"
          }
        ]
        command = ["node", "server.js"]
        health_check = {
          command = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        }
      }
    ]
  }

  resource_tags = {
    Environment = "prod"
    Team        = "platform"
  }
}
```

**What happens:**
- Creates a Fargate service running on the `prod-api` cluster
- Registers a task definition with 1 vCPU and 2 GB memory
- Attaches Datadog agent and Fluent Bit sidecars automatically
- Creates IAM roles with base execution permissions (ECR pull, CloudWatch logs, SSM parameters)
- Creates a security group with default egress (all outbound allowed)
- Configures autoscaling target (0-30 tasks) with scheduled scale-in/scale-out

### With Load Balancer

```hcl
inputs = {
  load_balancer = {
    create = true
    listeners = [
      { port = 443, protocol = "HTTPS" },
      { port = 80,  protocol = "HTTP" }
    ]
  }
}
```

**What happens:**
- Creates an internet-facing Application Load Balancer with dualstack addressing
- Creates a security group allowing HTTPS inbound
- Creates an IPv4 target group pointing to the service's container port
- Adds an ingress rule on the service security group allowing traffic from the load balancer

### With Additional IAM Policies

```hcl
inputs = {
  task_definition = {
    iam = {
      permissions_boundary = { ... }
      task_role = {
        additional_policies = [
          {
            Sid      = "AllowS3Access"
            Effect   = "Allow"
            Action   = ["s3:GetObject", "s3:PutObject"]
            Resource = "arn:aws:s3:::my-bucket/*"
          }
        ]
      }
      task_execution_role = {
        additional_policies = [
          {
            Sid      = "AllowSecretsManager"
            Effect   = "Allow"
            Action   = ["secretsmanager:GetSecretValue"]
            Resource = "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-secret-*"
          }
        ]
      }
    }
  }
}
```

**What happens:**
- The task role gets S3 access for your application containers
- The task execution role gets Secrets Manager access on top of the base permissions (ECR pull, CloudWatch logs, SSM parameters, ECS Exec, CloudMap)

### EC2 Launch Type

```hcl
inputs = {
  ecs_service = {
    launch_type = "EC2"
    cluster     = "ec2-cluster"
  }

  task_definition = {
    requires_compatibilities = ["EC2"]
    network_mode             = "bridge"

    container_definitions = [
      {
        name       = "my-service"
        image      = ""
        privileged = true
        linux_parameters = {
          devices = [
            { host_path = "/dev/sda1" }
          ]
        }
      }
    ]
  }
}
```

**What happens:**
- Creates an EC2-backed service with bridge networking
- Enables EC2-only features like privileged mode and host device access

## Why Two IAM Roles

ECS tasks use two distinct roles:

- **Task role** — assumed by your application containers. Grants permissions your code needs (S3, DynamoDB, SQS, etc.). The module creates this with no base statements; you provide everything via `additional_policies`.
- **Task execution role** — assumed by the ECS agent. Grants permissions to pull images, push logs, and read secrets. The module provides base statements for common operations and merges your `additional_policies` on top.

Both roles share a single permissions boundary to enforce maximum allowed permissions.

## Why Sidecars Are Hardcoded

The Datadog agent and Fluent Bit log forwarder are automatically added to every task definition. This ensures consistent observability across all services without requiring each caller to configure logging and monitoring. The application container's logs are routed through Fluent Bit to Datadog using the `awsfirelens` log driver.

## Configuration Variables

### `ecs_service`

- `ecs_service.name` — Service name as a map with `kebab_case` and `snake_case` keys
- `ecs_service.cluster` — ECS cluster name
- `ecs_service.launch_type` — `"FARGATE"` (default) or `"EC2"`
- `ecs_service.desired_count` — Initial task count (default: `1`)
- `ecs_service.deployment` — Circuit breaker, deployment strategy (rolling/canary/linear), ECS Exec
- `ecs_service.health_check.grace_period` — Seconds before health checks start (default: `10`)
- `ecs_service.security_group_rules` — Custom ingress/egress rules for the service security group
- `ecs_service.service_connect` — Service Connect configuration with Cloud Map namespace
- `ecs_service.service_discovery` — Service Discovery configuration (mutually exclusive with Service Connect)

### `task_definition`

- `task_definition.family` — Task definition family name
- `task_definition.cpu` / `memory` — Task-level resources (required for Fargate)
- `task_definition.requires_compatibilities` — `["FARGATE"]` (default) or `["EC2"]`
- `task_definition.runtime_platform` — OS family and CPU architecture
- `task_definition.ecr_repo` / `ecr_image_tag` — Container image source
- `task_definition.iam` — IAM roles, policies, and permissions boundary
- `task_definition.cloudwatch_log_group` — Log group name and retention
- `task_definition.ssm_parameters` — SSM parameters injected as container secrets
- `task_definition.container_definitions` — Application container configuration (ports, health check, command, etc.)
- `task_definition.volumes` — EFS, Docker, FSx, and bind mount volumes

### `load_balancer`

- `load_balancer.create` — Whether to create a load balancer (default: `false`)
- `load_balancer.internal` — Internal vs internet-facing (default: `false`)
- `load_balancer.type` — `"application"` (default), `"network"`, or `"gateway"`
- `load_balancer.listeners` — List of listener port/protocol/certificate configurations
- `load_balancer.target_groups` — Custom target groups (auto-generated if omitted)
- `load_balancer.security_group_rules` — Custom rules for the load balancer security group

### Other

- `aws` — Hosting AWS account and region metadata
- `vpc_name` — VPC name tag for subnet and security group placement
- `resource_tags` — Map of tags applied to all resources
- `autoscaling_target` — Min/max capacity for the autoscaling target
- `autoscaling_scheduled_scale_in` / `autoscaling_scheduled_scale_out` — Scheduled scaling actions

## Outputs

- `configuration.ecs_service` — Service ARN, name, ID, cluster, deployment settings, desired count
- `configuration.ecs_task_role` — Task role ARN, name, ID, assume role policy
- `configuration.ecs_task_execution_role` — Task execution role ARN, name, ID, assume role policy
