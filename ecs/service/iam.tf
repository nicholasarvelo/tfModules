locals {
  iam_name = format(
    "%s%s",
    lookup(
      local.package.name_shorthand.camelcase,
      var.ecs_service.name.kebab_case
    ),
    lookup(
      local.account.name_shorthand.camelcase,
      var.aws.account.name.snake_case
    )
  )

  # Base execution role statements that every ECS service needs
  base_task_execution_statements = [
    {
      Sid    = "AllowCloudWatchLogActions"
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:DescribeLogGroups"
      ]
      Resource = [
        format(
          "arn:aws:logs:%s:%s:log-group:/%s/%s*",
          data.aws_region.this.region,
          data.aws_caller_identity.this.account_id,
          var.ecs_service.name.kebab_case,
          var.aws.account.name.snake_case
        )
      ]
    },
    {
      Sid    = "AllowCloudWatchLogStreamActions"
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents"
      ]
      Resource = [
        format(
          "arn:aws:logs:%s:%s:log-group:/%s/%s:log-stream:*",
          data.aws_region.this.region,
          data.aws_caller_identity.this.account_id,
          var.ecs_service.name.kebab_case,
          var.aws.account.name.snake_case
        )
      ]
    },
    {
      Sid    = "AllowECSExec"
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
      ]
      Resource = "*"
    },
    {
      Sid    = "AllowECRImagePull"
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]
      Resource = "*"
    },
    {
      Sid    = "AllowCloudMapActions"
      Effect = "Allow"
      Action = [
        "servicediscovery:DeregisterInstance",
        "servicediscovery:RegisterInstance"
      ]
      Resource = "*"
    },
    {
      Sid    = "AllowSSMActions"
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      Resource = format(
        "arn:aws:ssm:%s:%s:parameter/%s/%s/*",
        data.aws_region.this.region,
        data.aws_caller_identity.this.account_id,
        var.ecs_service.name.kebab_case,
        var.aws.account.name.snake_case
      )
    }
  ]

  task_execution_policy_statements = concat(
    local.base_task_execution_statements,
    var.task_definition.iam.task_execution_role.additional_policies
  )

  task_role_policy_statements = var.task_definition.iam.task_role.additional_policies
}

resource "aws_iam_policy" "permissions_boundary" {
  name   = var.task_definition.iam.permissions_boundary.name
  path   = var.task_definition.iam.permissions_boundary.path
  policy = jsonencode(var.task_definition.iam.permissions_boundary.policy)

  tags = var.resource_tags
}

# Task Role — assumed by containers to interact with AWS services
resource "aws_iam_role" "ecs_task" {
  name                  = format("%sECSTask", local.iam_name)
  assume_role_policy    = jsonencode(var.task_definition.iam.task_role.assume_role_policy)
  permissions_boundary  = aws_iam_policy.permissions_boundary.arn
  force_detach_policies = true

  tags = var.resource_tags
}

resource "aws_iam_policy" "ecs_task" {
  name = format("%sECSTask", local.iam_name)
  path = "/"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.task_role_policy_statements
  })

  tags = var.resource_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task" {
  policy_arn = aws_iam_policy.ecs_task.arn
  role       = aws_iam_role.ecs_task.name
}

# Task Execution Role — grants ECS agent permission to pull images, push logs, read secrets
resource "aws_iam_role" "ecs_task_execution" {
  name                  = format("%sECSTaskExec", local.iam_name)
  assume_role_policy    = jsonencode(var.task_definition.iam.task_execution_role.assume_role_policy)
  permissions_boundary  = aws_iam_policy.permissions_boundary.arn
  force_detach_policies = true

  tags = var.resource_tags
}

resource "aws_iam_policy" "ecs_task_execution" {
  name = format("%sECSTaskExec", local.iam_name)
  path = "/"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.task_execution_policy_statements
  })

  tags = var.resource_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  policy_arn = aws_iam_policy.ecs_task_execution.arn
  role       = aws_iam_role.ecs_task_execution.name
}

resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ecs_task_execution.name

  lifecycle {
    enabled = var.ecs_service.deployment.execute_command.enable
  }
}
