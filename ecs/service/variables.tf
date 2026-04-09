variable "autoscaling_scheduled_scale_in" {
  type = object({
    name         = optional(string, "Scale In")
    enable       = optional(bool, true)
    schedule     = optional(string, "cron(0 22 ? * 1-4 *)")
    timezone     = optional(string, "US/Eastern")
    max_capacity = optional(number, 0)
    min_capacity = optional(number, 0)
  })
  description = "The scheduled action to scale in the ECS service"
  default     = {}
}

variable "autoscaling_scheduled_scale_out" {
  type = object({
    name         = optional(string, "Scale Out")
    enable       = optional(bool, true)
    schedule     = optional(string, "cron(0 9 ? * 1-6 *)")
    timezone     = optional(string, "US/Eastern")
    max_capacity = optional(number, 1)
    min_capacity = optional(number, 1)
  })
  description = "The scheduled action to scale out the ECS service"
  default     = {}
}

variable "autoscaling_target" {
  type = object({
    max_capacity       = optional(number, 30)
    min_capacity       = optional(number, 0)
    scalable_dimension = optional(string, "ecs:service:DesiredCount")
    service_namespace  = optional(string, "ecs")
  })
  description = "The autoscaling target for the ECS service"
  default     = {}
}

variable "aws" {
  type = object({
    account = object({
      id   = string
      name = map(string)
    })
    organization = object({
      id   = string
      name = map(string)
    })
    region = map(string)
  })
  description = "Hosting AWS account and region"
}

variable "ecs_service" {
  type = object({
    additional_security_group_ids = optional(list(string), [])
    availability_zone_rebalancing = optional(string, "ENABLED")
    cluster                       = string
    deployment = optional(object({
      circuit_breaker = optional(object({
        enable   = optional(bool, true)
        rollback = optional(bool, false)
      }), {})
      configuration = optional(object({
        bake_time_in_minutes = optional(number)
        canary_configuration = optional(object({
          enable                      = optional(bool, false)
          canary_bake_time_in_minutes = optional(number)
          canary_percentage           = optional(number)
        }), {})
        linear_configuration = optional(object({
          enable                    = optional(bool, false)
          step_bake_time_in_minutes = optional(number)
          step_percent              = optional(number)
        }), {})
        strategy = optional(string, "ROLLING")
      }), {})
      execute_command = optional(object({
        enable = optional(bool, false)
      }), {})
      maximum_percent = optional(number, 400)
      minimum_percent = optional(number, 100)
    }), {})
    desired_count = optional(number, 1)
    health_check = optional(object({
      grace_period = optional(number, 10)
    }), {})
    launch_type      = optional(string, "FARGATE")
    name             = map(string)
    platform_version = optional(string, "LATEST")
    security_group_rules = object({
      egress = optional(list(object({
        description                  = string
        cidr_ipv4                    = optional(string)
        cidr_ipv6                    = optional(string)
        ip_protocol                  = string
        from_port                    = optional(number)
        to_port                      = optional(number)
        referenced_security_group_id = optional(string)
      })), [])
      ingress = optional(list(object({
        description                  = string
        cidr_ipv4                    = optional(string)
        cidr_ipv6                    = optional(string)
        ip_protocol                  = string
        from_port                    = optional(number)
        to_port                      = optional(number)
        referenced_security_group_id = optional(string)
      })), [])
    })
    service_connect = optional(object({
      enable = optional(bool, false)
      log_configuration = optional(object({
        enable     = optional(bool, false)
        log_driver = optional(string, "awsfirelens")
        options    = optional(map(string), {})
      }), {})
      namespace_arn = optional(string)
      service = optional(list(object({
        port_name      = string
        discovery_name = optional(string)
        client_alias = object({
          port     = number
          dns_name = optional(string)
        })
      })), [])
    }), {})
    service_discovery = optional(object({
      description = optional(string)
      enable      = optional(bool, false)
      namespace = optional(object({
        arn  = optional(string)
        id   = optional(string)
        type = optional(string, "private_dns")
        dns_config = optional(object({
          record = optional(object({
            ttl  = optional(number, 30)
            type = optional(string, "A")
          }), {})
          routing_policy = optional(string, "MULTIVALUE")
        }), {})
        health_check = optional(object({
          failure_threshold = optional(number, 1)
          resource_path     = optional(string, "/")
          type              = optional(string, "HTTP")
        }), {})
      }), {})
      port_name = optional(string, "http")
    }), {})
  })
  description = "The configuration for the ECS service"

  validation {
    condition = (
      contains(
        ["DISABLED", "ENABLED"],
        var.ecs_service.availability_zone_rebalancing
      )
    )
    error_message = "The allowed values are 'DISABLED' or 'ENABLED'."
  }

  validation {
    condition     = var.ecs_service.health_check.grace_period <= 2147483647
    error_message = "The allowed maximum grace period is 2147483647 seconds"
  }

  validation {
    condition     = !(var.ecs_service.service_discovery.enable && var.ecs_service.service_connect.enable)
    error_message = "You cannot configure both Service Connect and Service Discovery"
  }

  validation {
    condition = contains(
      ["http", "private_dns", "public_dns"],
      var.ecs_service.service_discovery.namespace.type
    )
    error_message = "Valid namespace types are 'http', 'private_dns', or 'public_dns'"
  }

  validation {
    condition = contains(["HTTP", "HTTPS", "TCP"],
      var.ecs_service.service_discovery.namespace.health_check.type
    )
    error_message = "Valid health check types are 'HTTP', 'HTTPS', or 'TCP'"
  }
}

variable "load_balancer" {
  type = object({
    create          = optional(bool, false)
    internal        = optional(bool, false)
    ip_address_type = optional(string, "dualstack")
    listeners = optional(list(object({
      certificate_arn = optional(string)
      port            = number
      protocol        = string
    })), [])
    security_group_rules = optional(object({
      egress = optional(list(object({
        description                  = string
        cidr_ipv4                    = optional(string)
        cidr_ipv6                    = optional(string)
        ip_protocol                  = string
        from_port                    = optional(number)
        to_port                      = optional(number)
        referenced_security_group_id = optional(string)
      })), [])
      ingress = optional(list(object({
        description                  = string
        cidr_ipv4                    = optional(string)
        cidr_ipv6                    = optional(string)
        ip_protocol                  = string
        from_port                    = optional(number)
        to_port                      = optional(number)
        referenced_security_group_id = optional(string)
      })), [])
    }), {})
    target_groups = optional(list(object({
      health_check = object({
        healthy_threshold   = optional(number, 2)
        interval            = optional(number, 45)
        path                = optional(string)
        port                = optional(any, "traffic-port")
        timeout             = optional(number, 5)
        unhealthy_threshold = optional(number, 2)
      })
      ip_address_type = optional(string, "ipv4")
      name            = string
      port            = number
      protocol        = optional(string, "HTTP")
      target_type     = optional(string, "ip")
    })), [])
    type           = optional(string, "application")
    vpn_resolvable = optional(bool, false)
  })
  description = "The configuration for the ECS service load balancer"
  default     = {}

  validation {
    condition = (
      contains(["dualstack", "dualstack-without-public-ipv4", "ipv4"], var.load_balancer.ip_address_type)
    )
    error_message = "The allowed address types are 'dualstack', 'dualstack-without-public-ipv4', or 'ipv4'."
  }

  validation {
    condition = (
      contains(["application", "gateway", "network"], var.load_balancer.type)
    )
    error_message = "The allowed values are 'application', 'gateway', or 'network'"
  }
}

variable "resource_tags" {
  type        = map(string)
  description = "Map of tags to apply to deployed resources"
}

variable "vpc_name" {
  type        = string
  description = "The name of the VPC to deploy the ECS service to"
}
