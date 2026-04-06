variable "ecr_repository" {
  type = object({
    encryption_configuration = optional(object({
      encryption_type = optional(string, "AES256")
      kms_key_arn     = optional(string)
    }), {})
    force_delete = optional(bool, true)
    image_tag = optional(object({
      exclusion_filter = optional(list(object({
        filter      = string
        filter_type = string
      })), [])
      mutability = optional(string, "MUTABLE")
    }), {})
    name = string
    policy = optional(object({
      lifecycle = optional(object({
        rules = list(object({
          rulePriority = number
          description  = optional(string)
          selection = object({
            tagStatus   = string
            countType   = string
            countUnit   = optional(string)
            countNumber = number
          })
          action = object({
            type = string
          })
        }))
      }), null)
      repository = optional(object({
        version = optional(string, "2012-10-17")
        statement = list(object({
          sid    = optional(string)
          effect = string
          action = list(string)
          principal = object({
            aws = list(string)
          })
        }))
      }), null)
    }), {})
    region       = optional(string)
    scan_on_push = optional(bool, true)
  })
  description = "The name of the repository."
}

variable "file" {
  type = object({
    lifecycle_policy  = optional(string)
    repository_policy = optional(string)
  })
  description = "File path to JSON lifecycle and repository policies"
  default     = {}
}

variable "resource_tags" {
  type        = map(string)
  description = "Map of tags to apply to deployed resources"
  default     = {}
}
