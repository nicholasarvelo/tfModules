resource "aws_ecr_repository" "this" {
  name         = var.ecr_repository.name
  force_delete = var.ecr_repository.force_delete
  region       = var.ecr_repository.region

  encryption_configuration {
    encryption_type = var.ecr_repository.encryption_configuration.encryption_type
    kms_key         = var.ecr_repository.encryption_configuration.kms_key_arn
  }
  image_scanning_configuration {
    scan_on_push = var.ecr_repository.scan_on_push
  }
  image_tag_mutability = var.ecr_repository.image_tag.mutability

  dynamic "image_tag_mutability_exclusion_filter" {
    for_each = var.ecr_repository.image_tag.exclusion_filter
    content {
      filter      = image_tag_mutability_exclusion_filter.value.filter
      filter_type = image_tag_mutability_exclusion_filter.value.filter_type
    }
  }

  tags = var.resource_tags
}

locals {
  repository_policy = try(
    file(var.file.repository_policy),
    var.ecr_repository.policy.repository != null
      ? jsonencode(var.ecr_repository.policy.repository)
      : null
  )

  lifecycle_policy = try(
    file(var.file.lifecycle_policy),
    var.ecr_repository.policy.lifecycle != null
      ? jsonencode(var.ecr_repository.policy.lifecycle)
      : null
  )
}

resource "aws_ecr_repository_policy" "this" {
  policy     = local.repository_policy
  repository = aws_ecr_repository.this.name
  lifecycle {
    enabled = local.repository_policy != null
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  policy     = local.lifecycle_policy
  repository = aws_ecr_repository.this.name
  lifecycle {
    enabled = local.lifecycle_policy != null
  }
}
