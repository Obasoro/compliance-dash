# AWS Configuration
aws_region = "us-east-1"

# ECR Repository Configuration
repository_name = "obasorokunle"

# Security Settings (using AES256 to avoid KMS permissions)
image_tag_mutability = "MUTABLE"
scan_on_push         = true
encryption_type      = "AES256"  # Using AES256 instead of KMS

# Lifecycle Policy Settings
max_image_count      = 10
untagged_image_days  = 1
dev_image_count      = 5

# Cross-account access (disabled)
enable_cross_account_access = false

# Enhanced Docker Build Configuration
build_backend       = true   # Enable backend Docker build
build_frontend      = false  # Enable frontend Docker build (set to true if you have frontend/Dockerfile)
auto_push_images    = true   # Automatically push to ECR after build
docker_platform     = "linux/amd64"  # Docker platform
create_build_info   = true   # Create build-info.json with comprehensive metadata
force_rebuild       = false  # Force rebuild without cache (useful for debugging)
keep_images_locally = false  # Keep images locally after terraform destroy

# Tags
tags = {
  Environment = "development"
  Project     = "compliance-dash"
  Owner       = "obasorokunle"
  ManagedBy   = "terraform"
}
