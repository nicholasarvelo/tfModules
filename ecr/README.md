# ECR Module

This module provisions an Elastic Container Registry repository with optional lifecycle and repository policies. Policies can be provided inline as HCL objects or as paths to JSON files, the module handles encoding and conditional creation automatically.

## What Gets Created

When you provision a repository, the module automatically:

1. **Creates an ECR repository** with configurable encryption, image scanning, and tag mutability
2. **Applies a repository policy** (if provided) controlling cross-account or IAM access
3. **Applies a lifecycle policy** (if provided) for automated image cleanup

Policy resources are only created when a policy is actually supplied either via file path or inline variable.

## Examples

### Minimal Repository

```hcl
inputs = {
  ecr_repository = {
    name = "myServiceApp"
  }
}
```

**What happens:**
- Creates a repository with AES256 encryption
- Enables scan on push
- Sets tag mutability to MUTABLE
- No lifecycle or repository policies applied

### Repository with KMS Encryption and Lifecycle Policy

```hcl
inputs = {
  ecr_repository = {
    name = "my-app"
    encryption_configuration = {
      encryption_type = "KMS"
      kms_key_arn     = "arn:aws:kms:us-east-1:123456789012:key/example-key-id"
    }
    policy = {
      lifecycle = {
        rules = [
          {
            rulePriority = 1
            description  = "Expire untagged images older than 14 days"
            selection = {
              tagStatus   = "untagged"
              countType   = "sinceImagePushed"
              countUnit   = "days"
              countNumber = 14
            }
            action = {
              type = "expire"
            }
          }
        ]
      }
    }
  }
}
```

**What happens:**
- Creates a repository encrypted with a customer-managed KMS key
- Automatically expires untagged images after 14 days

### Repository with Cross-Account Access

```hcl
inputs = {
  ecr_repository = {
    name = "shared-app"
    policy = {
      repository = {
        statement = [
          {
            sid    = "CrossAccountAccess"
            effect = "Allow"
            action = ["ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
            principal = {
              aws = ["arn:aws:iam::123456789012:root"]
            }
          }
        ]
      }
    }
  }
}
```

### Policies from JSON Files

```hcl
inputs = {
  ecr_repository = {
    name = "my-app"
  }
  file = {
    lifecycle_policy  = "policies/lifecycle.json"
    repository_policy = "policies/repository.json"
  }
}
```

**What happens:**
- Reads policy JSON directly from the specified file paths
- File-based policies take precedence over inline variable policies

Sample `lifecycle_policy.json`:

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire untagged images older than 14 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 14
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

Sample `repository_policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CrossAccountAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": ["arn:aws:iam::123456789012:root"]
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ]
    }
  ]
}
```

### Immutable Tags with Exclusions

```hcl
inputs = {
  ecr_repository = {
    name = "my-app"
    image_tag = {
      mutability = "IMMUTABLE_WITH_EXCLUSION"
      exclusion_filter = [
        { filter = "latest*", filter_type = "WILDCARD" },
        { filter = "dev-*",   filter_type = "WILDCARD" }
      ]
    }
  }
}
```

## Why Two Policy Input Methods

The module accepts policies as either inline HCL objects or file paths because:

- **Inline objects** work well when policies are simple or generated dynamically
- **File paths** are better for complex policies managed separately or shared across modules
- File paths take precedence if both are provided, the file wins via `try()` fallback

## Configuration Variables

### Required

- `ecr_repository.name` - Repository name

### Optional

- `ecr_repository.encryption_configuration.encryption_type` - `"AES256"` (default) or `"KMS"`
- `ecr_repository.encryption_configuration.kms_key_arn` - KMS key ARN when using KMS encryption
- `ecr_repository.force_delete` - Delete repository even if it contains images (default: `true`)
- `ecr_repository.image_tag.mutability` - Tag mutability: `"MUTABLE"` (default), `"IMMUTABLE"`, `"IMMUTABLE_WITH_EXCLUSION"`, or `"MUTABLE_WITH_EXCLUSION"`
- `ecr_repository.image_tag.exclusion_filter` - List of tag filters with `filter` and `filter_type` fields
- `ecr_repository.policy.lifecycle` - Inline lifecycle policy object with `rules` list
- `ecr_repository.policy.repository` - Inline repository policy object with `statement` list
- `ecr_repository.region` - Override the provider region for this repository
- `ecr_repository.scan_on_push` - Enable image scanning on push (default: `true`)
- `file.lifecycle_policy` - Path to lifecycle policy JSON file
- `file.repository_policy` - Path to repository policy JSON file
- `resource_tags` - Map of tags to apply to the repository (default: `{}`)

## Outputs

- `configuration.arn` - Full ARN of the repository
- `configuration.id` - Registry ID where the repository was created
- `configuration.name` - Repository name
- `configuration.url` - Repository URL for docker push/pull
