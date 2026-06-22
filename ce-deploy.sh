#!/bin/sh
set -e

# Load OS information.
# shellcheck source=/dev/null
. /etc/os-release

usage(){
  /usr/bin/echo 'ce-deploy.sh [OPTIONS]'
  /usr/bin/echo 'Install the latest ce-deploy version, or the version specified as option.'
  /usr/bin/echo 'Please ensure you are using Debian Linux or similar and at least Bullseye (11) or higher.'
  /usr/bin/echo ''
  /usr/bin/echo 'Available options:'
  /usr/bin/echo '--build-id: the build-id of your application'
  /usr/bin/echo '--build-number: the build-number of your application'
  /usr/bin/echo '--install: perform a clean installation'
  /usr/bin/echo '--own-branch: the branch of ce-deploy to use, defaults to 1.x'
  /usr/bin/echo '--verbose: more verbose output from Ansible'
  /usr/bin/echo ''
}

# Parse options arguments.
parse_options(){
  while [ "${1:-}" ]; do
    case "$1" in
      "--build-id")
          shift
          BUILD_ID="$1"
        ;;
      "--build-number")
          shift
          BUILD_NUMBER="$1"
        ;;
      "--install")
          CLEAN_INSTALL="yes"
        ;;
      "--own-branch")
          shift
          OWN_BRANCH="$1"
        ;;
      "--verbose")
          VERBOSE="yes"
        ;;
        *)
        usage
        exit 1
        ;;
    esac
    shift
  done
}

# Set default variables.
BUILD_ID="ddev"
BUILD_NUMBER=0
CLEAN_INSTALL="no"
OWN_BRANCH="1.x"
VERBOSE="no"

parse_options "$@"

cd "$HOME/ce-deploy"
if [ "$CLEAN_INSTALL" = "yes" ] && [ -f "$HOME/ce-deploy/track/$BUILD_ID" ]; then
  rm "$HOME/ce-deploy/track/$BUILD_ID"
fi
CE_DEPLOY_ARGS="--build-id $BUILD_ID --build-number $BUILD_NUMBER --own-branch $OWN_BRANCH --playbook deploy/deploy-ddev.yml"
if [ "$VERBOSE" = "yes" ]; then
  CE_DEPLOY_ARGS="$CE_DEPLOY_ARGS --verbose"
fi
# shellcheck disable=SC2086
/bin/sh "$HOME/ce-deploy/scripts/deploy.sh" $CE_DEPLOY_ARGS --workspace /var/www/html
ANSIBLE_BUILD_RESULT=$?
if [ -n "$ANSIBLE_BUILD_RESULT" ] && [ "$ANSIBLE_BUILD_RESULT" = 0 ]; then
  TRACKFILE_OUTPUT=$(/bin/sh "${HOME}/ce-deploy/scripts/track-set.sh" --build-id "${BUILD_ID}" --previous-stable-build-number "${BUILD_NUMBER}")
  echo "Build number: $TRACKFILE_OUTPUT"
fi