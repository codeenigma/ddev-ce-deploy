#!/bin/bash

# This is a simple test script to validate the add-on structure
echo "Validating ddev-ce-deploy add-on structure..."

# Check that required files exist
required_files=(
  "install.yaml"
  ".ddev/web-build/Dockerfile"
  ".ddev/web-build/provision.yml"
  ".ddev/ce-deploy.sh"
  ".ddev/commands/web/deploy"
  "README.md"
)

for file in "${required_files[@]}"; do
  if [ -f "$file" ]; then
    echo "✓ $file exists"
  else
    echo "✗ $file missing"
    exit 1
  fi
done

# Check that commands directory is executable
if [ -x ".ddev/commands/web/deploy" ]; then
  echo "✓ Deploy command is executable"
else
  echo "✗ Deploy command is not executable"
  exit 1
fi

# Check that ce-deploy script is executable
if [ -x ".ddev/ce-deploy.sh" ]; then
  echo "✓ Deploy script is executable"
else
  echo "✗ Deploy script is not executable"
  exit 1
fi

echo "All validations passed!"
