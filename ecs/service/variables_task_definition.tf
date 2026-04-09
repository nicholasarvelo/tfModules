variable "task_definition" {
  description = "ECS task definition configuration supporting both Fargate and EC2 launch types"

  type = object({
    # Required
    family = string

    # Task-level settings
    cpu                      = optional(string)
    memory                   = optional(string)
    network_mode             = optional(string, "awsvpc")
    requires_compatibilities = optional(list(string), ["FARGATE"])

    runtime_platform = optional(object({
      operating_system_family = optional(string, "LINUX")
      cpu_architecture        = optional(string, "X86_64")
    }))

    # ECR image
    ecr_repo = optional(object({
      name = string
      id   = string
    }))
    ecr_image_tag = optional(string, "")

    # IAM
    iam = object({
      permissions_boundary = object({
        name   = string
        path   = string
        policy = any
      })
      task_role = object({
        assume_role_policy = optional(object({
          Version = optional(string, "2012-10-17")
          Statement = optional(list(object({
            Effect = optional(string, "Allow")
            Principal = optional(object({
              Service = optional(list(string), ["ecs-tasks.amazonaws.com"])
            }), {})
            Action    = optional(list(string), ["sts:AssumeRole"])
            Condition = optional(any)
          })), [])
        }), {})
        additional_policies = optional(list(object({
          Sid      = optional(string)
          Effect   = string
          Action   = list(string)
          Resource = any
        })), [])
      })
      task_execution_role = object({
        assume_role_policy = optional(object({
          Version = optional(string, "2012-10-17")
          Statement = optional(list(object({
            Effect = optional(string, "Allow")
            Principal = optional(object({
              Service = optional(list(string), ["ecs-tasks.amazonaws.com"])
            }), {})
            Action    = optional(list(string), ["sts:AssumeRole"])
            Condition = optional(any)
          })), [])
        }), {})
        additional_policies = optional(list(object({
          Sid      = optional(string)
          Effect   = string
          Action   = list(string)
          Resource = any
        })), [])
      })
    })

    # CloudWatch log group
    cloudwatch_log_group = optional(object({
      name              = string
      retention_in_days = optional(number, 14)
    }))

    # SSM parameters (secrets injected into container)
    ssm_parameters = optional(object({
      string = optional(list(object({
        name      = string
        valueFrom = string
      })), [])
      secure_string = optional(list(object({
        name      = string
        valueFrom = string
      })), [])
    }), {})

    # Container definitions
    container_definitions = list(object({
      name                = string
      image               = string
      version_consistency = optional(string)
      essential           = optional(bool, true)
      cpu                 = optional(number)
      memory              = optional(number)
      memory_reservation  = optional(number)

      port_mappings = optional(list(object({
        container_port = number
        host_port      = optional(number)
        protocol       = optional(string, "tcp")
        name           = optional(string)
        app_protocol   = optional(string)
      })), [])

      repository_credentials = optional(object({
        credentials_parameter = string
      }))

      command           = optional(list(string))
      entry_point       = optional(list(string))
      working_directory = optional(string)
      user              = optional(string)

      environment = optional(list(object({
        name  = string
        value = string
      })), [])

      environment_files = optional(list(object({
        value = string
        type  = optional(string, "s3")
      })), [])

      secrets = optional(list(object({
        name       = string
        value_from = string
      })), [])

      health_check = optional(object({
        command      = list(string)
        interval     = optional(number, 30)
        timeout      = optional(number, 5)
        retries      = optional(number, 3)
        start_period = optional(number, 0)
      }))

      restart_policy = optional(object({
        enabled                = bool
        ignored_exit_codes     = optional(list(number))
        restart_attempt_period = optional(number, 300)
      }))

      disable_networking = optional(bool)
      links              = optional(list(string))
      hostname           = optional(string)
      dns_servers        = optional(list(string))
      dns_search_domains = optional(list(string))
      extra_hosts = optional(list(object({
        hostname   = string
        ip_address = string
      })))

      readonly_root_filesystem = optional(bool, false)

      mount_points = optional(list(object({
        source_volume  = string
        container_path = string
        read_only      = optional(bool, false)
      })), [])

      volumes_from = optional(list(object({
        source_container = string
        read_only        = optional(bool, false)
      })), [])

      log_configuration = optional(object({
        log_driver = string
        options    = optional(map(string), {})
        secret_options = optional(list(object({
          name       = string
          value_from = string
        })), [])
      }))

      firelens_configuration = optional(object({
        type    = string
        options = optional(map(string), {})
      }))

      privileged              = optional(bool)
      docker_security_options = optional(list(string))
      credential_specs        = optional(list(string))

      linux_parameters = optional(object({
        init_process_enabled = optional(bool)
        shared_memory_size   = optional(number)
        max_swap             = optional(number)
        swappiness           = optional(number)
        capabilities = optional(object({
          add  = optional(list(string), [])
          drop = optional(list(string), [])
        }))
        devices = optional(list(object({
          host_path      = string
          container_path = optional(string)
          permissions    = optional(list(string))
        })), [])
        tmpfs = optional(list(object({
          container_path = string
          size           = number
          mount_options  = optional(list(string))
        })), [])
      }))

      resource_requirements = optional(list(object({
        value = string
        type  = string
      })), [])

      depends_on_containers = optional(list(object({
        container_name = string
        condition      = string
      })), [])

      start_timeout = optional(number)
      stop_timeout  = optional(number)

      ulimits = optional(list(object({
        name       = string
        soft_limit = number
        hard_limit = number
      })), [])

      system_controls = optional(list(object({
        namespace = string
        value     = string
      })), [])

      docker_labels   = optional(map(string), {})
      interactive     = optional(bool)
      pseudo_terminal = optional(bool)
    }))

    # Volumes
    volumes = optional(list(object({
      name                 = string
      configured_at_launch = optional(bool)
      host = optional(object({
        source_path = optional(string)
      }))
      docker_volume_configuration = optional(object({
        scope         = optional(string)
        autoprovision = optional(bool, false)
        driver        = optional(string)
        driver_opts   = optional(map(string), {})
        labels        = optional(map(string), {})
      }))
      efs_volume_configuration = optional(object({
        file_system_id          = string
        root_directory          = optional(string)
        transit_encryption      = optional(string)
        transit_encryption_port = optional(number)
        authorization_config = optional(object({
          access_point_id = optional(string)
          iam             = optional(string)
        }))
      }))
      fsx_windows_file_server_volume_configuration = optional(object({
        file_system_id = string
        root_directory = string
        authorization_config = object({
          credentials_parameter = string
          domain                = string
        })
      }))
    })), [])

    # Placement constraints (EC2 only)
    placement_constraints = optional(list(object({
      type       = string
      expression = optional(string)
    })), [])

    # Proxy configuration (App Mesh)
    proxy_configuration = optional(object({
      type           = optional(string, "APPMESH")
      container_name = string
      properties = optional(list(object({
        name  = string
        value = string
      })), [])
    }))

    # Inference accelerators (EC2 only)
    inference_accelerators = optional(list(object({
      device_name = string
      device_type = string
    })), [])

    # Other task-level params
    ephemeral_storage = optional(object({
      size_in_gib = number
    }))

    pid_mode               = optional(string)
    ipc_mode               = optional(string)
    enable_fault_injection = optional(bool, false)
  })
}
