#!/usr/bin/env bash
# Helper functions for ddev get-db command

# Global variables
CONFIG_FILE=".ddev/config.yaml"
GET_DB_PROJECT=""
GET_DB_DEFAULT_CREDS=""
ENV_HOST=""
ENV_USER=""
ENV_PATH=""
ENV_CREDS=""
ENV_DB=""

# Logging functions
log_verbose() {
  if [[ "$VERBOSE" == true ]]; then
    echo "[VERBOSE] $*" >&2
  fi
}

log_info() {
  echo "$*"
}

log_error() {
  echo "[ERROR] $*" >&2
}

log_warn() {
  echo "[WARN] $*" >&2
}

# Configuration Management
load_get_db_config() {
  # CONFIG_FILE should be relative to project root (where ddev is run)
  CONFIG_FILE=".ddev/config.yaml"
  
  if [[ ! -f "$CONFIG_FILE" ]]; then
    log_verbose "Config file not found: $CONFIG_FILE"
    return
  fi

  log_verbose "Loading config from: $CONFIG_FILE"

  # Simple YAML parsing with grep/sed - works without yq or PHP yaml extension
  # Get project name
  GET_DB_PROJECT=$(sed -n '/^get_db:/,/^[^ ]/p' "$CONFIG_FILE" 2>/dev/null | grep "project:" | head -1 | sed 's/.*project:[[:space:]]*//' | tr -d '"' | tr -d "'")
  
  # Get environment-specific settings (accounts for proper YAML indentation)
  ENV_HOST=$(sed -n '/^get_db:/,/^[^ ]/p' "$CONFIG_FILE" 2>/dev/null | grep -A 3 "^    ${ENVIRONMENT}:" | grep "host:" | head -1 | sed 's/.*host:[[:space:]]*//' | tr -d '"' | tr -d "'")
  ENV_USER=$(sed -n '/^get_db:/,/^[^ ]/p' "$CONFIG_FILE" 2>/dev/null | grep -A 3 "^    ${ENVIRONMENT}:" | grep "user:" | head -1 | sed 's/.*user:[[:space:]]*//' | tr -d '"' | tr -d "'")

  log_verbose "Loaded config: project='$GET_DB_PROJECT', host='$ENV_HOST', user='$ENV_USER'"
}

save_get_db_config() {
  local save_project="${1:-true}"
  local save_host="${2:-true}"
  
  if [[ ! -f "$CONFIG_FILE" ]]; then
    log_warn "Config file not found, cannot save settings"
    return
  fi

  if command -v yq &> /dev/null; then
    # Ensure get_db section exists
    yq -i '.get_db //= {}' "$CONFIG_FILE" 2>/dev/null || true
    yq -i '.get_db.environments //= {}' "$CONFIG_FILE" 2>/dev/null || true
    yq -i ".get_db.environments.${ENVIRONMENT} //= {}" "$CONFIG_FILE" 2>/dev/null || true

    # Set values conditionally
    if [[ "$save_project" == true && -n "$PROJECT" ]]; then
      yq -i ".get_db.project = \"$PROJECT\"" "$CONFIG_FILE" 2>/dev/null && log_verbose "Saved project: $PROJECT"
    fi
    if [[ "$save_host" == true && -n "$HOST" ]]; then
      yq -i ".get_db.environments.${ENVIRONMENT}.host = \"$HOST\"" "$CONFIG_FILE" 2>/dev/null && log_verbose "Saved host for $ENVIRONMENT: $HOST"
    fi
    if [[ -n "$USER" && "$USER" != "deploy" ]]; then
      yq -i ".get_db.environments.${ENVIRONMENT}.user = \"$USER\"" "$CONFIG_FILE" 2>/dev/null && log_verbose "Saved user for $ENVIRONMENT: $USER"
    fi
  else
    # Fallback: Use sed/awk to update YAML (no external dependencies)
    log_verbose "Saving config with sed/awk fallback..."
    
    # Create temp file
    local temp_config=$(mktemp)
    
    # Check if get_db section exists
    if ! grep -q "^get_db:" "$CONFIG_FILE"; then
      # Add get_db section at end of file
      echo "" >> "$CONFIG_FILE"
      echo "get_db:" >> "$CONFIG_FILE"
      echo "  project: $PROJECT" >> "$CONFIG_FILE"
      echo "  environments:" >> "$CONFIG_FILE"
      echo "    ${ENVIRONMENT}:" >> "$CONFIG_FILE"
      echo "      host: $HOST" >> "$CONFIG_FILE"
      log_info "Configuration saved to $CONFIG_FILE"
      return
    fi
    
    # Check if environments section exists
    if ! grep -q "environments:" "$CONFIG_FILE"; then
      # Add environments after get_db.project
      awk -v proj="$PROJECT" -v env="$ENVIRONMENT" -v host="$HOST" '
        /^get_db:/{print; next}
        /^  project:/{print; print "  environments:"; print "    " env ":"; print "      host: " host; next}
        {print}
      ' "$CONFIG_FILE" > "$temp_config" && mv "$temp_config" "$CONFIG_FILE"
      log_info "Configuration saved to $CONFIG_FILE"
      return
    fi
    
    # Check if environment section exists
    if ! grep -q "^    ${ENVIRONMENT}:" "$CONFIG_FILE"; then
      # Add environment section after environments:
      awk -v env="$ENVIRONMENT" -v host="$HOST" '
        /^  environments:/{print; print "    " env ":"; print "      host: " host; next}
        {print}
      ' "$CONFIG_FILE" > "$temp_config" && mv "$temp_config" "$CONFIG_FILE"
      log_info "Configuration saved to $CONFIG_FILE"
      return
    fi
    
    # Update existing values
    # Update project
    if [[ "$save_project" == true && -n "$PROJECT" ]]; then
      sed -i "s/^  project:.*/  project: $PROJECT/" "$CONFIG_FILE"
    fi
    
    # Update host for this environment
    if [[ "$save_host" == true && -n "$HOST" ]]; then
      awk -v env="$ENVIRONMENT" -v host="$HOST" '
        BEGIN { in_env=0 }
        /^    [a-zA-Z0-9_-]+:/{
          if (in_env) { in_env=0 }
          gsub(/:/,"",$1)
          if ($1 == env) { in_env=1 }
        }
        in_env && /^      host:/{
          print "      host: " host
          in_env=0
          next
        }
        {print}
      ' "$CONFIG_FILE" > "$temp_config" && mv "$temp_config" "$CONFIG_FILE"
    fi
    
    log_info "Configuration saved to $CONFIG_FILE"
  fi
}

get_remote_path() {
  if [[ -n "$ENV_PATH" ]]; then
    echo "$ENV_PATH"
  else
    # Default pattern: /home/{user}/deploy/{project}_{env}/live.{project}_{env}
    echo "/home/${USER}/deploy/${PROJECT}_${ENVIRONMENT}/live.${PROJECT}_${ENVIRONMENT}"
  fi
}

get_mysql_creds_path() {
  if [[ -n "$MYSQL_CREDS" ]]; then
    echo "$MYSQL_CREDS"
  elif [[ -n "$ENV_CREDS" ]]; then
    echo "$ENV_CREDS"
  elif [[ -n "$GET_DB_DEFAULT_CREDS" ]]; then
    echo "$GET_DB_DEFAULT_CREDS"
  else
    echo "/home/${USER}/.mysql.creds"
  fi
}

# Interactive Prompts
prompt_project() {
  if [[ -n "$GET_DB_PROJECT" ]]; then
    PROJECT="$GET_DB_PROJECT"
    log_info "Using saved project: $PROJECT"
    return
  fi

  # Check if we're in an interactive terminal
  if [[ ! -t 0 ]]; then
    log_error "Project name is required but not provided and not running in interactive mode."
    log_info "Please provide --project <name> or run interactively."
    exit 1
  fi

  read -rp "Enter project name: " PROJECT
  while [[ -z "$PROJECT" ]]; do
    log_error "Project name is required"
    read -rp "Enter project name: " PROJECT
  done
}

prompt_host() {
  if [[ -n "$ENV_HOST" ]]; then
    HOST="$ENV_HOST"
    log_info "Using saved host for $ENVIRONMENT: $HOST"
    return
  fi

  # Check if we're in an interactive terminal
  if [[ ! -t 0 ]]; then
    log_error "Host is required but not provided and not running in interactive mode."
    log_info "Please provide --host <hostname> or run interactively."
    exit 1
  fi

  read -rp "Enter remote host (e.g., dev.example.com): " HOST
  while [[ -z "$HOST" ]]; do
    log_error "Host is required"
    read -rp "Enter remote host (e.g., dev.example.com): " HOST
  done
}

# SSH Functions
check_ssh_agent() {
  if ! command -v ssh-add &> /dev/null; then
    log_error "ssh-add not found. Please ensure SSH is installed."
    exit 1
  fi

  if ! ssh-add -l &> /dev/null; then
    log_error "No SSH keys found in agent. Add a key with: ssh-add ~/.ssh/id_ed25519"
    log_info "Or generate a new key with: ssh-keygen -t ed25519"
    exit 1
  fi

  log_verbose "SSH agent has keys loaded"
}

ssh_exec() {
  local cmd="$1"
  local ssh_opts="-A -o BatchMode=yes -o ConnectTimeout=10"

  # SSH as local user, then use sudo to switch to remote user
  ssh $ssh_opts "${HOST}" "sudo -i -u ${USER} bash -c \"$cmd\""
}

ssh_exec_heredoc() {
  local ssh_opts="-A -o BatchMode=yes -o ConnectTimeout=10"

  ssh $ssh_opts "${HOST}" "$1"
}

# Database Detection
detect_database_name() {
  local project_type="$1"
  local remote_path
  remote_path=$(get_remote_path)
  local cmd=""
  local ssh_opts="-A -o BatchMode=yes -o ConnectTimeout=10"

  case "$project_type" in
    drupal8|drupal9|drupal10|drupal11)
      cmd="cd $remote_path && grep -E \"^\\s*['\\\"]database['\\\"]\\s*=>\" web/sites/default/settings.php 2>/dev/null | head -1 | sed \"s/.*['\\\"]database['\\\"]\\s*=>\\s*['\\\"]\\([^'\\\"]*\\)['\\\"].*/\\1/\" || true"
      ;;
    drupal7)
      cmd="cd $remote_path && grep -A5 \"'default' => array\" sites/default/settings.php 2>/dev/null | grep \"'database'\" | head -1 | sed \"s/.*'database'\\s*=>\\s*'\\([^']*\\)'.*/\\1/\" || true"
      ;;
    drupal6)
      cmd="cd $remote_path && grep \"^\\$db_url\" sites/default/settings.php 2>/dev/null | sed \"s/.*\\/\\([^\\/]*\\)\\?.*/\\1/\" || true"
      ;;
    wordpress)
      cmd="cd $remote_path && grep \"define.*DB_NAME\" wp-config.php 2>/dev/null | sed \"s/.*DB_NAME.*['\\\"]\\([^'\\\"]*\\)['\\\"].*/\\1/\" || true"
      ;;
    laravel|craftcms)
      cmd="cd $remote_path && grep \"^DB_DATABASE=\" .env 2>/dev/null | cut -d'=' -f2 | tr -d '\"' || true"
      ;;
    magento|magento2)
      cmd="cd $remote_path && grep -A10 \"'db'\" app/etc/env.php 2>/dev/null | grep \"'dbname'\" | head -1 | sed \"s/.*'dbname'\\s*=>\\s*'\\([^']*\\)'.*/\\1/\" || true"
      ;;
    symfony)
      cmd="cd $remote_path && grep \"^DATABASE_URL=\" .env 2>/dev/null | sed \"s/.*@[^\\/]*\\/\\([^:?]*\\).*/\\1/\" || true"
      ;;
    *)
      log_verbose "No database detection for project type: $project_type"
      echo ""
      return
      ;;
  esac

  log_verbose "Detecting database with: $cmd"
  
  # Execute command: SSH as local user, then use sudo to switch to remote user
  local raw_result
  raw_result=$(ssh $ssh_opts "${HOST}" "sudo -i -u ${USER} bash -c \"$cmd\"" 2>&1)
  local exit_code=$?
  
  log_verbose "SSH exit code: $exit_code"
  log_verbose "Raw SSH output: '$raw_result'"
  
  # Clean the result
  local result
  result=$(echo "$raw_result" | tr -d '\n\r' | xargs 2>/dev/null || echo "")
  
  log_verbose "Cleaned result: '$result'"
  
  if [[ -n "$result" ]]; then
    echo "$result"
  else
    echo ""
  fi
}

# Validation
validate_project_name() {
  if [[ ! "$PROJECT" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid project name. Use only alphanumeric characters, underscores, and hyphens."
    exit 1
  fi
}

validate_environment_name() {
  if [[ ! "$ENVIRONMENT" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid environment name. Use only alphanumeric characters, underscores, and hyphens."
    exit 1
  fi
}
