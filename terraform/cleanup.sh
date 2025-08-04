#!/bin/bash
# Remove old docker-build.tf and rename enhanced version
rm -f docker-build.tf
mv docker-build-enhanced.tf docker-build.tf
echo "Cleanup complete - using enhanced Docker build configuration"
