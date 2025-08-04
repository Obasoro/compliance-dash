# Docker Build Automation with Terraform

This document explains the automated Docker image build process integrated with your ECR Terraform configuration.

## Overview

The Terraform configuration automatically:
- Builds Docker images from your source code
- Tags images with Git commit hashes, branches, and version tags
- Pushes images to ECR repositories
- Creates build metadata for tracking

## Features

### 🏷️ Smart Tagging Strategy
Images are automatically tagged with:
- **Git Tags**: `v1.0.0` (if tagged commit)
- **Branch + Commit**: `main-abc1234` (if no tag)
- **Commit Hash**: `abc1234`
- **Branch Latest**: `main-latest`
- **Latest**: `latest`

### 🔄 Automatic Builds
- Triggers on source code changes
- Detects changes in `package.json`
- Rebuilds when Git commit changes
- Supports both backend and frontend

### 📦 Multi-Component Support
- **Backend**: Uses existing `backend/Dockerfile`
- **Frontend**: Optional `frontend/Dockerfile` support
- **Separate ECR repositories** for each component

## Configuration

### Variables in `terraform.tfvars`

```hcl
# Docker Build Configuration
build_backend     = true   # Enable backend Docker build
build_frontend    = false  # Enable frontend Docker build
auto_push_images  = true   # Automatically push to ECR
docker_platform   = "linux/amd64"  # Docker platform
create_build_info = true   # Create build metadata file
```

### Build Arguments

Your Dockerfile automatically receives these build arguments:
- `GIT_COMMIT`: Short commit hash
- `GIT_BRANCH`: Current branch name
- `GIT_TAG`: Git tag (if on tagged commit)
- `BUILD_DATE`: Build timestamp
- `VERSION`: Computed version tag

## Usage

### Automatic Build (Recommended)

```bash
cd terraform/
terraform apply
```

This will:
1. Detect Git information
2. Build Docker images
3. Tag with appropriate versions
4. Push to ECR repositories

### Manual Build Commands

Get manual build commands from Terraform output:
```bash
terraform output build_commands
```

### Version Information in Container

Your application can access version info via environment variables:
```bash
echo $GIT_COMMIT    # abc1234
echo $GIT_BRANCH    # main
echo $VERSION       # v1.0.0 or main-abc1234
echo $BUILD_DATE    # 20240804-152030
```

## Build Process Flow

1. **Git Information Extraction**
   ```bash
   git rev-parse --short HEAD          # Get commit hash
   git rev-parse --abbrev-ref HEAD     # Get branch name
   git describe --tags --exact-match   # Get tag (if exists)
   ```

2. **Version Tag Generation**
   - If on tagged commit: Use git tag (`v1.0.0`)
   - Otherwise: Use `{branch}-{commit}` (`main-abc1234`)

3. **Docker Build**
   - Build with version build args
   - Tag with multiple versions
   - Push to ECR (if enabled)

4. **Metadata Generation**
   - Create `build-info.json` with build details
   - Include all generated tags

## File Structure

```
compliance-dash/
├── backend/
│   ├── Dockerfile          # Enhanced with build args
│   └── package.json        # Triggers rebuild on change
├── frontend/
│   ├── Dockerfile          # Optional, auto-detected
│   └── package.json        # Triggers rebuild on change
├── terraform/
│   ├── main.tf            # ECR repositories
│   ├── docker-build.tf    # Docker build automation
│   ├── variables.tf       # Build configuration
│   └── outputs.tf         # Build outputs
└── build-info.json       # Generated build metadata
```

## Example Outputs

### Git Information
```json
{
  "commit_hash": "abc1234",
  "branch": "main",
  "tag": "v1.0.0",
  "timestamp": "20240804-152030"
}
```

### Generated Tags
```json
{
  "version_tag": "v1.0.0",
  "backend_tags": [
    "latest",
    "v1.0.0",
    "abc1234",
    "main-latest"
  ],
  "frontend_tags": [
    "latest",
    "v1.0.0-frontend",
    "abc1234-frontend",
    "main-frontend-latest"
  ]
}
```

### Build Info File
```json
{
  "build_timestamp": "20240804-152030",
  "git_commit": "abc1234",
  "git_branch": "main",
  "git_tag": "v1.0.0",
  "version_tag": "v1.0.0",
  "backend_image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/obasorokunle:v1.0.0",
  "frontend_image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/obasorokunle-frontend:v1.0.0-frontend",
  "tags": {
    "backend": ["latest", "v1.0.0", "abc1234", "main-latest"],
    "frontend": ["latest", "v1.0.0-frontend", "abc1234-frontend", "main-frontend-latest"]
  }
}
```

## Deployment Strategies

### Development Workflow
```bash
# Make changes to code
git add .
git commit -m "feature: add new functionality"
git push

# Build and deploy
cd terraform/
terraform apply  # Builds with commit hash tag
```

### Release Workflow
```bash
# Tag release
git tag v1.0.0
git push origin v1.0.0

# Build and deploy
cd terraform/
terraform apply  # Builds with v1.0.0 tag
```

### Hotfix Workflow
```bash
# Create hotfix branch
git checkout -b hotfix/critical-fix
git commit -m "fix: critical issue"
git push

# Build and deploy
cd terraform/
terraform apply  # Builds with hotfix/critical-fix-abc1234 tag
```

## Troubleshooting

### Build Failures
1. **Docker not running**: Ensure Docker daemon is running
2. **Git not found**: Ensure git is installed and repository is initialized
3. **Permission denied**: Check Docker permissions and ECR access

### Common Issues

**Issue**: `git: command not found`
**Solution**: Install git or run from git-enabled environment

**Issue**: `docker: permission denied`
**Solution**: Add user to docker group or use sudo

**Issue**: `ECR push failed`
**Solution**: Check AWS credentials and ECR permissions

### Debug Commands
```bash
# Check git information
cd terraform/
terraform console
> data.external.git_info.result

# Check Docker images
docker images | grep obasorokunle

# Check ECR repositories
aws ecr describe-repositories
```

## Best Practices

1. **Use Git Tags** for production releases
2. **Keep Dockerfiles optimized** with multi-stage builds
3. **Monitor image sizes** and layer caching
4. **Use semantic versioning** for tags
5. **Test builds locally** before applying Terraform

## Integration with CI/CD

This setup works great with CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Deploy Infrastructure
  run: |
    cd terraform/
    terraform init
    terraform apply -auto-approve
```

The build process will automatically use the CI environment's Git information for tagging.
