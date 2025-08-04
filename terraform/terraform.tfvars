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

# Tags
tags = {
  Environment = "development"
  Project     = "compliance-dash"
  Owner       = "obasorokunle"
  ManagedBy   = "terraform"
}
