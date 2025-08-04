# Amazon ECR Repository Terraform Configuration

This Terraform configuration creates an Amazon Elastic Container Registry (ECR) repository with comprehensive security features, lifecycle policies, and encryption settings.

## Features

- **Secure ECR Repository** with configurable encryption (AES256 or KMS)
- **Lifecycle Policies** to automatically manage image retention
- **Image Scanning** on push for vulnerability detection
- **KMS Encryption** with automatic key rotation
- **Cross-Account Access** support (optional)
- **Comprehensive Tagging** for resource management

## Architecture

The configuration creates:

1. **ECR Repository** - Main container registry
2. **KMS Key & Alias** - For enhanced encryption (optional)
3. **Lifecycle Policy** - Automated image cleanup
4. **Repository Policy** - Cross-account access control (optional)

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0 installed
- Appropriate IAM permissions for ECR, KMS, and related services

### Required IAM Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:*",
        "kms:CreateKey",
        "kms:CreateAlias",
        "kms:DescribeKey",
        "kms:GetKeyPolicy",
        "kms:PutKeyPolicy",
        "kms:TagResource",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

## Quick Start

1. **Clone and Navigate**
   ```bash
   cd terraform/
   ```

2. **Copy Example Variables**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit Variables**
   ```bash
   nano terraform.tfvars
   ```
   Update the `repository_name` and other settings as needed.

4. **Initialize Terraform**
   ```bash
   terraform init
   ```

5. **Plan Deployment**
   ```bash
   terraform plan
   ```

6. **Apply Configuration**
   ```bash
   terraform apply
   ```

## Configuration Options

### Basic Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `repository_name` | ECR repository name | - | Yes |
| `aws_region` | AWS region | `us-east-1` | No |
| `image_tag_mutability` | Tag mutability (MUTABLE/IMMUTABLE) | `MUTABLE` | No |

### Security Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `encryption_type` | Encryption type (AES256/KMS) | `AES256` | No |
| `scan_on_push` | Enable vulnerability scanning | `true` | No |
| `kms_deletion_window` | KMS key deletion window (days) | `10` | No |

### Lifecycle Policy Configuration

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `max_image_count` | Max tagged images to keep | `10` | No |
| `untagged_image_days` | Days to keep untagged images | `1` | No |
| `dev_image_count` | Max development images to keep | `5` | No |

## Lifecycle Policy Rules

The configuration includes three lifecycle rules:

1. **Production Images**: Keeps the last N tagged images with "v" prefix
2. **Untagged Images**: Deletes untagged images after specified days
3. **Development Images**: Keeps the last N images with "dev", "feature", or "hotfix" prefixes

## Usage Examples

### Basic Usage
```hcl
# terraform.tfvars
repository_name = "my-app"
aws_region     = "us-west-2"
```

### Production Setup with KMS
```hcl
# terraform.tfvars
repository_name      = "my-production-app"
aws_region          = "us-west-2"
encryption_type     = "KMS"
image_tag_mutability = "IMMUTABLE"
max_image_count     = 50
```

### Cross-Account Access
```hcl
# terraform.tfvars
repository_name             = "shared-service"
enable_cross_account_access = true
allowed_account_ids         = ["123456789012", "987654321098"]
```

## Outputs

After deployment, you'll get:

- `repository_url` - ECR repository URL for Docker commands
- `repository_arn` - Full ARN of the repository
- `kms_key_arn` - KMS key ARN (if KMS encryption is used)
- `docker_push_commands` - Ready-to-use Docker commands

## Docker Usage

After deployment, use the output commands to push images:

```bash
# Get the commands from Terraform output
terraform output docker_push_commands

# Example usage:
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

docker build -t my-app .
docker tag my-app:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:latest
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:latest
```

## Security Best Practices

1. **Use KMS Encryption** for sensitive workloads
2. **Set IMMUTABLE tags** for production repositories
3. **Enable scan_on_push** for vulnerability detection
4. **Use specific IAM policies** with least privilege
5. **Regular lifecycle policy reviews** to optimize costs

## Cost Optimization

- Lifecycle policies automatically clean up old images
- Untagged images are deleted after 1 day by default
- Development images are limited to reduce storage costs
- Consider using AES256 encryption to avoid KMS costs for non-sensitive workloads

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure AWS credentials are configured
   - Verify IAM permissions include ECR and KMS actions

2. **Repository Name Invalid**
   - Use lowercase letters, numbers, hyphens, underscores, periods only
   - Cannot start or end with special characters

3. **KMS Key Access**
   - Ensure the AWS account has permissions to create KMS keys
   - Check KMS key policies if using existing keys

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

**Warning**: This will delete the ECR repository and all images. Make sure to backup any important images first.

## Contributing

1. Follow Terraform best practices
2. Update documentation for any new variables
3. Test changes in a development environment first
4. Use semantic versioning for releases
