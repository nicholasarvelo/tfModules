variable "aws" {
  type = object({
    account = optional(object({
      id   = string
      name = map(string)
    }))
    organization = optional(object({
      id   = string
      name = map(string)
    }))
    region = optional(map(string))
  })
  description = "Hosting AWS account and region"
  default     = {}
}

variable "ecs_cluster" {
  type = object({
    container_insights = optional(string, "enabled")
    name               = map(string)
    service_discovery = object({
      enable        = optional(bool, true)
      namespace_arn = optional(string)
    })
    vpc = object({
      id   = optional(string)
      name = optional(string)
      security_group = optional(object({
        create = optional(bool, true)
      }), {})
    })
  })
  description = "ECS cluster configuration"

  validation {
    condition = contains(
      ["enhanced", "enabled", "disabled"],
      var.ecs_cluster.container_insights
    )
    error_message = "Valid container insights value is 'enhanced', 'enabled', or 'disabled'"
  }

  validation {
    condition = (
      var.ecs_cluster.service_discovery.enable == false ||
      (
        var.ecs_cluster.service_discovery.namespace_arn != null
        && var.ecs_cluster.service_discovery.namespace_arn != ""
      )
    )
    error_message = "When service discovery is enabled, namespace ARN must be provided."
  }
}

variable "resource_tags" {
  type        = map(string)
  description = "Map of resource tags"
  default     = {}
}
