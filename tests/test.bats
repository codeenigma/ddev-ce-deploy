#!/usr/bin/env bats

# Test for ddev-ce-deploy add-on
# This is a skeleton test file - you should customize it for your specific add-on

@test "add-on installs successfully" {
  # Test that we can install the add-on
  run ddev add-on get . --project test-project
  [ "$status" -eq 0 ]
}

@test "deploy command exists" {
  # Test that the deploy command is properly installed
  cd test-project
  run ddev help deploy
  [ "$status" -eq 0 ]
  cd ..
}

@test "ce-deploy script exists" {
  # Test that ce-deploy script is properly installed
  cd test-project
  run test -f .ddev/ce-deploy.sh
  [ "$status" -eq 0 ]
  cd ..
}

@test "web-build directory exists" {
  # Test that web-build directory is properly installed
  cd test-project
  run test -d .ddev/web-build
  [ "$status" -eq 0 ]
  cd ..
}