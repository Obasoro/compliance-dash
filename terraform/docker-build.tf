# Enhanced Docker Build Automation with kreuzwerker/docker provider
# This file provides robust Docker image building and ECR pushing with proper authentication

# Data sources for Git information with error handling
data "external" "git_info" {
  program = ["bash", "-c", <<-EOT
    cd ${path.root}/..
    echo '{'
    echo '  "commit_hash": "'$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")'",'
    echo '  "commit_full": "'$(git rev-parse HEAD 2>/dev/null || echo "unknown")'",'
    echo '  "branch": "'$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")'",'
    echo '  "tag": "'$(git describe --tags --exact-match 2>/dev/null || echo "")'",'
    echo '  "timestamp": "'$(date -u +%Y%m%d-%H%M%S)'",'
    echo '  "repo_clean": "'$(git diff --quiet && git diff --cached --quiet && echo "true" || echo "false" 2>/dev/null)'"'
    echo '}'
  EOT
  ]
}

# Local values for consistent image tagging and ECR URLs
locals {
  git_commit     = data.external.git_info.result.commit_hash
  git_commit_full = data.external.git_info.result.commit_full
  git_branch     = data.external.git_info.result.branch
  git_tag        = data.external.git_info.result.tag
  timestamp      = data.external.git_info.result.timestamp
  repo_clean     = data.external.git_info.result.repo_clean == "true"
  
  # ECR registry URL
  ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  
  # Determine version tag priority: git tag > branch-commit > commit
  version_tag = local.git_tag != "" ? local.git_tag : "${local.git_branch}-${local.git_commit}"
  
  # Consistent base tags for traceability
  base_tags = {
    latest      = "latest"
    version     = local.version_tag
    commit      = local.git_commit
    commit_full = local.git_commit_full
    branch      = "${local.git_branch}-latest"
    timestamp   = local.timestamp
  }
  
  # Backend image tags with full traceability
  backend_tags = [
    local.base_tags.latest,
    local.base_tags.version,
    local.base_tags.commit,
    local.base_tags.branch,
    "build-${local.base_tags.timestamp}"
  ]
  
  # Frontend image tags with frontend suffix
  frontend_tags = [
    "${local.base_tags.latest}-frontend",
    "${local.base_tags.version}-frontend",
    "${local.base_tags.commit}-frontend",
    "${local.base_tags.branch}-frontend",
    "build-${local.base_tags.timestamp}-frontend"
  ]
  
  # Full image names for repositories
  backend_image_base = "${local.ecr_registry}/${aws_ecr_repository.main.name}"
  frontend_image_base = var.build_frontend ? "${local.ecr_registry}/${aws_ecr_repository.frontend[0].name}" : null
}

# Backend Docker Image Build using kreuzwerker/docker provider
resource "docker_image" "backend" {
  count = var.build_backend ? 1 : 0
  
  name = "${local.backend_image_base}:${local.base_tags.version}"
  
  build {
    context    = "${path.root}/../backend"
    dockerfile = "Dockerfile"
    
    # Build args for version information
    build_args = {
      GIT_COMMIT    = local.git_commit
      GIT_BRANCH    = local.git_branch
      GIT_TAG       = local.git_tag
      BUILD_DATE    = local.timestamp
      VERSION       = local.version_tag
      COMMIT_FULL   = local.git_commit_full
      REPO_CLEAN    = tostring(local.repo_clean)
    }
    
    # Platform for multi-arch builds
    platform = var.docker_platform
    
    # Remove intermediate containers
    remove = true
    
    # Force rebuild triggers
    no_cache = var.force_rebuild
  }
  
  # Triggers for rebuilding
  triggers = {
    source_hash    = filemd5("${path.root}/../backend/package.json")
    dockerfile_hash = filemd5("${path.root}/../backend/Dockerfile")
    git_commit     = local.git_commit
    build_args     = md5(jsonencode({
      GIT_COMMIT  = local.git_commit
      GIT_BRANCH  = local.git_branch
      GIT_TAG     = local.git_tag
      BUILD_DATE  = local.timestamp
      VERSION     = local.version_tag
    }))
  }
  
  # Keep image after terraform destroy (optional)
  keep_locally = var.keep_images_locally
}

# Frontend Docker Image Build (if frontend has Dockerfile)
resource "docker_image" "frontend" {
  count = var.build_frontend && fileexists("${path.root}/../frontend/Dockerfile") ? 1 : 0
  
  name = "${local.frontend_image_base}:${local.base_tags.version}-frontend"
  
  build {
    context    = "${path.root}/../frontend"
    dockerfile = "Dockerfile"
    
    build_args = {
      GIT_COMMIT    = local.git_commit
      GIT_BRANCH    = local.git_branch
      GIT_TAG       = local.git_tag
      BUILD_DATE    = local.timestamp
      VERSION       = local.version_tag
      COMMIT_FULL   = local.git_commit_full
      REPO_CLEAN    = tostring(local.repo_clean)
    }
    
    platform = var.docker_platform
    remove   = true
    no_cache = var.force_rebuild
  }
  
  triggers = {
    source_hash     = try(filemd5("${path.root}/../frontend/package.json"), "")
    dockerfile_hash = try(filemd5("${path.root}/../frontend/Dockerfile"), "")
    git_commit      = local.git_commit
    build_args      = md5(jsonencode({
      GIT_COMMIT  = local.git_commit
      GIT_BRANCH  = local.git_branch
      GIT_TAG     = local.git_tag
      BUILD_DATE  = local.timestamp
      VERSION     = local.version_tag
    }))
  }
  
  keep_locally = var.keep_images_locally
}

# Frontend ECR Repository (separate from backend)
resource "aws_ecr_repository" "frontend" {
  count = var.build_frontend ? 1 : 0
  
  name                 = "${var.repository_name}-frontend"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.encryption_type == "KMS" ? aws_kms_key.ecr[0].arn : null
  }

  tags = merge(var.tags, {
    Component = "frontend"
  })
}

# Frontend ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "frontend" {
  count = var.build_frontend ? 1 : 0
  
  repository = aws_ecr_repository.frontend[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.max_image_count} frontend images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "main", "develop"]
          countType     = "imageCountMoreThan"
          countNumber   = var.max_image_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged frontend images older than ${var.untagged_image_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Docker Registry Image for Backend with multiple tags using kreuzwerker/docker
resource "docker_registry_image" "backend" {
  count = var.build_backend && var.auto_push_images ? length(local.backend_tags) : 0
  
  name = "${local.backend_image_base}:${local.backend_tags[count.index]}"
  
  # Keep the pushed image reference
  keep_remotely = true
  
  # Triggers for re-pushing
  triggers = {
    image_id = var.build_backend ? docker_image.backend[0].image_id : ""
    tag      = local.backend_tags[count.index]
  }
  
  # Ensure tags are created before pushing
  depends_on = [docker_tag.backend_tags]
}

# Docker Registry Image for Frontend with multiple tags
resource "docker_registry_image" "frontend" {
  count = var.build_frontend && var.auto_push_images && fileexists("${path.root}/../frontend/Dockerfile") ? length(local.frontend_tags) : 0
  
  name = "${local.frontend_image_base}:${local.frontend_tags[count.index]}"
  
  keep_remotely = true
  
  triggers = {
    image_id = var.build_frontend ? docker_image.frontend[0].image_id : ""
    tag      = local.frontend_tags[count.index]
  }
  
  # Ensure tags are created before pushing
  depends_on = [docker_tag.frontend_tags]
}

# Tag backend image with all required tags before pushing
resource "docker_tag" "backend_tags" {
  count = var.build_backend ? length(local.backend_tags) : 0
  
  source_image = docker_image.backend[0].image_id
  target_image = "${local.backend_image_base}:${local.backend_tags[count.index]}"
  
  depends_on = [docker_image.backend]
}

# Tag frontend image with all required tags before pushing
resource "docker_tag" "frontend_tags" {
  count = var.build_frontend && fileexists("${path.root}/../frontend/Dockerfile") ? length(local.frontend_tags) : 0
  
  source_image = docker_image.frontend[0].image_id
  target_image = "${local.frontend_image_base}:${local.frontend_tags[count.index]}"
  
  depends_on = [docker_image.frontend]
}

# Build info output file with comprehensive metadata
resource "local_file" "build_info" {
  count = var.create_build_info ? 1 : 0
  
  filename = "${path.root}/../build-info.json"
  content = jsonencode({
    build_metadata = {
      timestamp       = local.timestamp
      terraform_run   = formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())
      ecr_registry    = local.ecr_registry
      docker_platform = var.docker_platform
    }
    git_info = {
      commit_hash = local.git_commit
      commit_full = local.git_commit_full
      branch      = local.git_branch
      tag         = local.git_tag
      repo_clean  = local.repo_clean
      version_tag = local.version_tag
    }
    images = {
      backend = var.build_backend ? {
        repository = aws_ecr_repository.main.repository_url
        base_name  = local.backend_image_base
        primary_tag = local.base_tags.version
        all_tags   = local.backend_tags
        image_id   = var.build_backend ? docker_image.backend[0].image_id : null
      } : null
      frontend = var.build_frontend && fileexists("${path.root}/../frontend/Dockerfile") ? {
        repository = aws_ecr_repository.frontend[0].repository_url
        base_name  = local.frontend_image_base
        primary_tag = "${local.base_tags.version}-frontend"
        all_tags   = local.frontend_tags
        image_id   = docker_image.frontend[0].image_id
      } : null
    }
    deployment_info = {
      backend_image_url  = var.build_backend ? "${local.backend_image_base}:${local.base_tags.version}" : null
      frontend_image_url = var.build_frontend && fileexists("${path.root}/../frontend/Dockerfile") ? "${local.frontend_image_base}:${local.base_tags.version}-frontend" : null
      pull_commands = {
        backend  = var.build_backend ? "docker pull ${local.backend_image_base}:${local.base_tags.version}" : null
        frontend = var.build_frontend && fileexists("${path.root}/../frontend/Dockerfile") ? "docker pull ${local.frontend_image_base}:${local.base_tags.version}-frontend" : null
      }
    }
  })
  
  depends_on = [
    docker_image.backend,
    docker_image.frontend,
    docker_registry_image.backend,
    docker_registry_image.frontend
  ]
}
