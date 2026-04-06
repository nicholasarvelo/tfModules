output "configuration" {
  value = {
    arn  = aws_ecr_repository.this.arn
    id   = aws_ecr_repository.this.registry_id
    name = aws_ecr_repository.this.name
    url  = aws_ecr_repository.this.repository_url
  }
}
