variable "ipv6_config" {
  type = object({
    private_subnet_offset = optional(number, 8)
    subnet_prefix_length  = optional(number, 4)
  })
  description = "IPv6 subnet configuration. private_subnet_offset determines the starting index for private subnets in IPv6 space."
  default     = {}
}

variable "nat_gateway_config" {
  type = object({
    subnet_index = optional(number, 0)
  })
  description = "NAT Gateway configuration. subnet_index specifies which public subnet (by index) to place the NAT gateway in."
  default     = {}
}

variable "max_subnets_per_type" {
  type        = number
  description = "Maximum number of subnets allowed per type (public/private)."
  default     = 6
}

variable "service_endpoints" {
  type = object({
    configure_gateway = optional(object({
      dynamodb = optional(bool, false)
      s3       = optional(bool, false)
    }), {})
    configure_interface = optional(object({
      cloudwatch_logs          = optional(bool, false)
      dms                      = optional(bool, false)
      ec2_messages             = optional(bool, false)
      ecr_api                  = optional(bool, false)
      ecr_docker               = optional(bool, false)
      firehose                 = optional(bool, false)
      kms                      = optional(bool, false)
      lambda                   = optional(bool, false)
      rds                      = optional(bool, false)
      redshift                 = optional(bool, false)
      secrets_manager          = optional(bool, false)
      sns                      = optional(bool, false)
      sqs                      = optional(bool, false)
      systems_manager          = optional(bool, false)
      systems_manager_messages = optional(bool, false)
    }), {})
  })
  description = "Endpoint services to configure for the VPC."
  default     = {}
}

variable "custom_service_endpoints" {
  type = object({
    gateway   = optional(map(string), {})
    interface = optional(map(string), {})
  })
  description = "Custom VPC endpoint service names. Keys are endpoint identifiers, values are service names (e.g., 'com.amazonaws.us-east-1.servicename')."
  default     = {}
}

variable "vpc" {
  type = object({
    assign_generated_ipv6_cidr_block = optional(bool, true)
    enable_dns_hostnames             = optional(bool, true)
    enable_dns_support               = optional(bool, true)
    cidr_block                       = string
    name                             = string
    routes = optional(object({
      private = optional(list(object({
        carrier_gateway_id         = optional(string, null)
        cidr_block                 = optional(string, null)
        core_network_arn           = optional(string, null)
        description                = optional(string, null)
        destination_prefix_list_id = optional(string, null)
        egress_only_gateway_id     = optional(string, null)
        gateway_id                 = optional(string, null)
        ipv6_cidr_block            = optional(string, null)
        local_gateway_id           = optional(string, null)
        nat_gateway_id             = optional(string, null)
        network_interface_id       = optional(string, null)
        transit_gateway_id         = optional(string, null)
        vpc_endpoint_id            = optional(string, null)
        vpc_peering_connection_id  = optional(string, null)
      })), [])
      public = optional(list(object({
        carrier_gateway_id         = optional(string, null)
        cidr_block                 = optional(string, null)
        core_network_arn           = optional(string, null)
        description                = optional(string, null)
        destination_prefix_list_id = optional(string, null)
        egress_only_gateway_id     = optional(string, null)
        gateway_id                 = optional(string, null)
        ipv6_cidr_block            = optional(string, null)
        local_gateway_id           = optional(string, null)
        nat_gateway_id             = optional(string, null)
        network_interface_id       = optional(string, null)
        transit_gateway_id         = optional(string, null)
        vpc_endpoint_id            = optional(string, null)
        vpc_peering_connection_id  = optional(string, null)
      })), [])
    }), {})
    subnets = optional(object({
      auto_provision = optional(object({
        disable              = optional(bool, false)
        private_subnet_count = optional(number, 6)
        public_subnet_count  = optional(number, 6)
      }), {})
      private = optional(list(string), [])
      public  = optional(list(string), [])
    }), {})
  })
  description = "The VPC configuration."

  validation {
    condition = (
      length(var.vpc.subnets.private) <= var.max_subnets_per_type &&
      length(var.vpc.subnets.public) <= var.max_subnets_per_type
    )
    error_message = "Number of subnets exceeds the configured maximum per type."
  }
}

variable "resource_tags" {
  type        = map(string)
  description = "Map of tags to apply to deployed resources"
  default     = {}
}
