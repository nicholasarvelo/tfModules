locals {
  # Compiles the ECR image URL.
  ecr_image_url = (
    format("%s:%s",
      data.aws_ecr_repository.this.repository_url, var.task_definition.ecr_image_tag
    )
  )

  ssm_parameters = concat(
    var.task_definition.ssm_parameters.string,
    var.task_definition.ssm_parameters.secure_string
  )
}

locals {
  # Fluent Bit's Datadog plugin supports assigning tags to service logs.
  # These tags need to be compiled into a single comma-separated string list of
  # key:value pairs. (e.g. "key1:value1, key2:value2, key3:value3")
  dd_tag_aws_account_id = format("aws_account_id:%s", var.aws.account.id)
  dd_tag_aws_account    = format("aws_account_name:%s", var.aws.account.name.kebab_case)
  dd_tag_aws_region     = format("aws_region:%s", var.aws.region.kebab_case)
  dd_tag_env            = format("env:%s", var.aws.account.name.kebab_case)
  dd_tag_environment    = format("environment:%s", var.aws.account.name.kebab_case)
  dd_tag_image_package  = format("image_package:%s", var.ecs_service.name.kebab_case)
  dd_tag_image_tag      = format("image_tag:%s", var.task_definition.ecr_image_tag)
  dd_tag_name = (
    format(
      "name:%s",
      format(
        "%s-%s", var.ecs_service.name.kebab_case, var.aws.account.name.kebab_case
      )
    )
  )

  dd_tags = (join(",",
    [
      local.dd_tag_aws_account_id,
      local.dd_tag_aws_account,
      local.dd_tag_aws_region,
      local.dd_tag_env,
      local.dd_tag_environment,
      local.dd_tag_image_package,
      local.dd_tag_image_tag,
      local.dd_tag_name,
    ]
  ))
}

# When modifying the task definition, only focus on adjusting the 'secrets[]'
# array. Keep all other settings unchanged. Ensure that the number of
# objects '{}' in the array corresponds to the expected environment variables
# for the container. You can achieve this by removing or duplicating existing
# objects as needed. Afterward, update the 'name' value and set the SSM
# parameter's suffix to match the updated 'name' value.
resource "aws_ecs_task_definition" "this" {
  family = format(
    "%s-%s",
    var.ecs_service.name.kebab_case,
    var.aws.account.name.kebab_case
  )
  network_mode       = var.task_definition.network_mode
  cpu                = var.task_definition.cpu
  memory             = var.task_definition.memory
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn
  container_definitions = jsonencode([
    {
      name        = var.ecs_service.name.kebab_case
      image       = local.ecr_image_url
      essential   = true
      user        = var.task_definition.container_definitions[0].user
      command     = var.task_definition.container_definitions[0].command
      entryPoint  = var.task_definition.container_definitions[0].entry_point
      environment = []
      mountPoints = [
        for mount in var.task_definition.container_definitions[0].mount_points : {
          sourceVolume  = mount.source_volume
          containerPath = mount.container_path
          readOnly      = mount.read_only
        }
      ]
      linuxParameters = {
        initProcessEnabled = true
      }
      secrets = local.ssm_parameters
      portMappings = [
        for mapping in var.task_definition.container_definitions[0].port_mappings : {
          containerPort = mapping.container_port
          name          = mapping.name
          protocol      = mapping.protocol
        }
      ]
      logConfiguration = {
        logDriver = "awsfirelens"
        options = {
          Name       = "datadog"
          apiKey     = data.aws_ssm_parameter.datadog_api_key.value
          dd_service = var.ecs_service.name.kebab_case
          dd_source  = "fargate"
          dd_tags    = local.dd_tags
          provider   = "ecs"
          tls        = "on"
        }
      }

      healthCheck = {
        command     = var.task_definition.container_definitions[0].health_check.command
        interval    = var.task_definition.container_definitions[0].health_check.interval
        timeout     = var.task_definition.container_definitions[0].health_check.timeout
        retries     = var.task_definition.container_definitions[0].health_check.retries
        startPeriod = var.task_definition.container_definitions[0].health_check.start_period
      }
      ulimits = [
        {
          name      = "nofile"
          softLimit = 4096
          hardLimit = 4096
        }
      ]
    },
    {
      name      = "datadog-agent"
      image     = "public.ecr.aws/datadog/agent:latest"
      essential = true
      portMappings = [
        {
          hostPort      = 8126
          protocol      = "tcp"
          containerPort = 8126
        }
      ]
      environment = [
        {
          name  = "ECS_FARGATE"
          value = "true"
        },
        {
          name  = "DD_AUTOCONFIG_INCLUDE_FEATURES",
          value = "ecsfargate"
        },
        {
          name  = "DD_CLOUD_PROVIDER_METADATA",
          value = "aws"
        },
        {
          name  = "DD_ECS_TASK_COLLECTION_ENABLED",
          value = "true"
        },
        {
          name  = "DD_PROCESS_AGENT_PROCESS_COLLECTION_ENABLED",
          value = "true"
        },
        {
          name  = "DD_APM_NON_LOCAL_TRAFFIC",
          value = "true"
        }
      ]
      secrets = [
        {
          name = "DD_API_KEY"
          valueFrom = (
            format(
              "arn:aws:ssm:%s:%s:parameter/%s/%s/DATADOG_API_KEY",
              var.aws.region.kebab_case,
              var.aws.account.id,
              var.ecs_service.name.kebab_case,
              var.aws.account.name.kebab_case
            )
          )
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group = (
            format(
              "/%s/%s",
              var.ecs_service.name.kebab_case,
              var.aws.account.name.kebab_case
            )
          )
          awslogs-region        = var.aws.region.kebab_case
          awslogs-stream-prefix = var.ecs_service.name.kebab_case
        }
      }
    },
    {
      name      = "fluent-bit-log-forwarder"
      image     = "public.ecr.aws/aws-observability/aws-for-fluent-bit:latest"
      essential = true
      firelensConfiguration = {
        type = "fluentbit"
        options = {
          enable-ecs-log-metadata = "true"
          config-file-type        = "file"
          config-file-value       = "/fluent-bit/configs/parse-json.conf"
        }
      }
      user = "0"
    }
  ])
  requires_compatibilities = var.task_definition.requires_compatibilities
  pid_mode                 = var.task_definition.pid_mode
  runtime_platform {
    operating_system_family = var.task_definition.runtime_platform.operating_system_family
    cpu_architecture        = var.task_definition.runtime_platform.cpu_architecture
  }

  dynamic "volume" {
    for_each = var.task_definition.volumes
    content {
      name                = volume.value.name
      configure_at_launch = volume.value.configured_at_launch

      dynamic "docker_volume_configuration" {
        for_each = volume.value.docker_volume_configuration != null ? [volume.value.docker_volume_configuration] : []
        content {
          driver = docker_volume_configuration.value.driver
          scope  = docker_volume_configuration.value.scope
          driver_opts = (
            length(docker_volume_configuration.value.driver_opts) > 0 ?
            docker_volume_configuration.value.driver_opts : null
          )
        }
      }

      dynamic "efs_volume_configuration" {
        for_each = volume.value.efs_volume_configuration != null ? [volume.value.efs_volume_configuration] : []
        content {
          file_system_id          = efs_volume_configuration.value.file_system_id
          root_directory          = efs_volume_configuration.value.root_directory
          transit_encryption      = efs_volume_configuration.value.transit_encryption
          transit_encryption_port = efs_volume_configuration.value.transit_encryption_port

          dynamic "authorization_config" {
            for_each = efs_volume_configuration.value.authorization_config != null ? [efs_volume_configuration.value.authorization_config] : []
            content {
              access_point_id = authorization_config.value.access_point_id
              iam             = authorization_config.value.iam
            }
          }
        }
      }

      dynamic "fsx_windows_file_server_volume_configuration" {
        for_each = volume.value.fsx_windows_file_server_volume_configuration != null ? [volume.value.fsx_windows_file_server_volume_configuration] : []
        content {
          file_system_id = fsx_windows_file_server_volume_configuration.value.file_system_id
          root_directory = fsx_windows_file_server_volume_configuration.value.root_directory

          authorization_config {
            credentials_parameter = fsx_windows_file_server_volume_configuration.value.authorization_config.credentials_parameter
            domain                = fsx_windows_file_server_volume_configuration.value.authorization_config.domain
          }
        }
      }
    }
  }

  tags = var.resource_tags
}

# This creates a CloudWatch log group with a retention policy
# to prevent logs from accumulating indefinitely and incurring unnecessary
# operational costs.
resource "aws_cloudwatch_log_group" "this" {
  name              = var.task_definition.cloudwatch_log_group.name
  retention_in_days = var.task_definition.cloudwatch_log_group.retention_in_days
  tags              = var.resource_tags
}
