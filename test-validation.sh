#!/bin/bash

# This is a simple test script to validate the add-on structure
echo "Validating ddev-ce-deploy add-on structure..."

# Check that required files exist (source directory structure)
required_files=(
  "install.yaml"
  "web-build/Dockerfile"
  "web-build/provision.yml"
  "ce-deploy.sh"
  "commands/web/deploy"
  "commands/host/get-db"
  "commands/host/lib/get-db-functions.sh"
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

# Check that deploy command is executable
if [ -x "commands/web/deploy" ]; then
  echo "✓ Deploy command is executable"
else
  echo "✗ Deploy command is not executable"
  exit 1
fi

# Check that ce-deploy script is executable
if [ -x "ce-deploy.sh" ]; then
  echo "✓ Deploy script is executable"
else
  echo "✗ Deploy script is not executable"
  exit 1
fi

# Check that get-db command is executable
if [ -x "commands/host/get-db" ]; then
  echo "✓ Get-db command is executable"
else
  echo "✗ Get-db command is not executable"
  exit 1
fi

# Check that get-db functions library is executable
if [ -x "commands/host/lib/get-db-functions.sh" ]; then
  echo "✓ Get-db functions library is executable"
else
  echo "✗ Get-db functions library is not executable"
  exit 1
fi

# Check DDEV command headers in get-db
if grep -q "## Description:.*Fetch database" "commands/host/get-db"; then
  echo "✓ Get-db has valid DDEV headers"
else
  echo "✗ Get-db missing or has invalid DDEV headers"
  exit 1
fi

# Check that get-db uses ExecHost
if grep -q "## ExecHost: true" "commands/host/get-db"; then
  echo "✓ Get-db correctly runs on host"
else
  echo "✗ Get-db should have ExecHost: true"
  exit 1
fi

# Check DDEV command headers in deploy
if grep -q "## Description:.*ce-deploy" "commands/web/deploy"; then
  echo "✓ Deploy has valid DDEV headers"
else
  echo "✗ Deploy missing or has invalid DDEV headers"
  exit 1
fi

echo "All validations passed!"
