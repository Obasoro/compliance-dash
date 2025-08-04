output "repository_arn" {
  description = "Full ARN of the ECR repository"
  value       = aws_ecr_repository.main.arn
}

output "repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.main.name
}

output "repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.main.repository_url
}

output "registry_id" {
  description = "Registry ID where the repository was created"
  value       = aws_ecr_repository.main.registry_id
}

output "kms_key_id" {
  description = "KMS key ID used for encryption (if KMS encryption is enabled)"
  value       = var.encryption_type == "KMS" ? aws_kms_key.ecr[0].key_id : null
}

output "kms_key_arn" {
  description = "KMS key ARN used for encryption (if KMS encryption is enabled)"
  value       = var.encryption_type == "KMS" ? aws_kms_key.ecr[0].arn : null
}

output "kms_alias_name" {
  description = "KMS key alias name (if KMS encryption is enabled)"
  value       = var.encryption_type == "KMS" ? aws_kms_alias.ecr[0].name : null
}

output "docker_push_commands" {
  description = "Commands to push Docker images to this ECR repository"
  value = [
    "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.main.repository_url}",
    "docker build -t ${aws_ecr_repository.main.name} .",
    "docker tag ${aws_ecr_repository.main.name}:latest ${aws_ecr_repository.main.repository_url}:latest",
    "docker push ${aws_ecr_repository.main.repository_url}:latest"
  ]
}
