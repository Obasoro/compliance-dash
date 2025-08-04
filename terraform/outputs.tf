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

# Enhanced Docker Build Outputs
output "git_info" {
  description = "Comprehensive Git information used for image tagging"
  value = {
    commit_hash = try(data.external.git_info.result.commit_hash, "unknown")
    commit_full = try(data.external.git_info.result.commit_full, "unknown")
    branch      = try(data.external.git_info.result.branch, "unknown")
    tag         = try(data.external.git_info.result.tag, "")
    timestamp   = try(data.external.git_info.result.timestamp, "unknown")
    repo_clean  = try(data.external.git_info.result.repo_clean == "true", false)
    version_tag = try(local.version_tag, "unknown")
  }
}

output "image_tags" {
  description = "Generated image tags for built images"
  value = {
    version_tag   = try(local.version_tag, "unknown")
    backend_tags  = try(local.backend_tags, [])
    frontend_tags = try(local.frontend_tags, [])
  }
}

output "backend_image_url" {
  description = "Backend Docker image URL with version tag"
  value       = var.build_backend ? "${aws_ecr_repository.main.repository_url}:${try(local.version_tag, "latest")}" : null
}

output "frontend_repository_url" {
  description = "Frontend ECR repository URL (if enabled)"
  value       = var.build_frontend ? try(aws_ecr_repository.frontend[0].repository_url, null) : null
}

output "frontend_image_url" {
  description = "Frontend Docker image URL with version tag"
  value       = var.build_frontend && fileexists("${path.root}/../frontend/Dockerfile") ? "${aws_ecr_repository.frontend[0].repository_url}:${try(local.version_tag, "latest")}-frontend" : null
}

output "build_commands" {
  description = "Commands to manually build and push images"
  value = {
    backend = var.build_backend ? [
      "cd ../backend",
      "docker build -t ${aws_ecr_repository.main.repository_url}:${try(local.version_tag, "latest")} --build-arg GIT_COMMIT=${try(local.git_commit, "unknown")} --build-arg VERSION=${try(local.version_tag, "latest")} .",
      "docker push ${aws_ecr_repository.main.repository_url}:${try(local.version_tag, "latest")}"
    ] : []
    frontend = var.build_frontend && fileexists("${path.root}/../frontend/Dockerfile") ? [
      "cd ../frontend",
      "docker build -t ${aws_ecr_repository.frontend[0].repository_url}:${try(local.version_tag, "latest")}-frontend --build-arg GIT_COMMIT=${try(local.git_commit, "unknown")} --build-arg VERSION=${try(local.version_tag, "latest")} .",
      "docker push ${aws_ecr_repository.frontend[0].repository_url}:${try(local.version_tag, "latest")}-frontend"
    ] : []
  }
}
