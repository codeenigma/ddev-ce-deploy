# ddev-ce-deploy

This is a DDEV add-on that prepares any project to use the [DDEV local development tool](https://ddev.com/) combined with [`ce-deploy`](https://gitlab.com/code-enigma/ce-deploy), the Ansible-based code deployment tool by [Code Enigma](https://www.codeenigma.com/).

## Installation

Install this add-on with:

```bash
ddev add-on get codeenigma/ddev-ce-deploy
```

## Usage

Once installed, you can use the custom `ddev deploy` command to deploy your application using `ce-deploy`.

```bash
ddev deploy
```

### Available Options

The deploy command supports the following flags:

- `--install` - perform a clean installation
- `--own-branch` - specify a feature branch to use
- `--build-id` - change the build ID (defaults to `ddev`)
- `--verbose` - additional verbosity for the Ansible output

## Prerequisites

* You have installed DDEV.
* You are running an up to date version of DDEV (at least 1.25.0)
* You are running a Mac or Linux workstation.
* To actually run the `ddev deploy` command you have created an Ansible playbook at `./deploy/deploy-ddev.yml` ([instructions below](#using-ce-deploy))

Windows users can still use these tools, but you will have to follow the steps in the script manually, because the installer is a Linux shell script.

## How it works

This add-on installs `ce-deploy` in the DDEV web container and provides a custom `ddev deploy` command that wraps the `ce-deploy` functionality.

## What is included

* A `.ddev/web-build/Dockerfile` that installs `ce-deploy` on the web container
* The `.ddev/web-build/provision.yml` file the `Dockerfile` needs in order to install Ansible and `ce-deploy` properly using our [`ce-provision`](https://gitlab.com/code-enigma/ce-provision) server management tool
* The `ce-deploy.sh` script that executes `ce-deploy` in the web container
* A custom command for deploying applications, `.ddev/commands/web/deploy` which is called with `ddev deploy` - this supports the following flag combinations:
  * no flags - this is a standard `ce-deploy` deployment with Ansible
  * `--install` - this is a clean install
  * `--own-branch` - useful if you are developing `ce-deploy` features, let's you specify a feature branch to use
  * `--build-id` - this defaults to `ddev` but you can change it if you need
  * `--verbose` - additional verbosity for the Ansible output

There is a help message provided by the custom command which you can read by entering `ddev help deploy`.

## Using `ce-deploy`

Because it is a wrapper for Ansible, it cannot work if a playbook does not exist. The command expects to find an Ansible playbook at `./deploy/deploy-ddev.yml` in your repository, which it will pass to `ce-deploy` for execution. If that playbook does not exist then the command will simply exit with an error message.

Because `ce-deploy` is almost infinitely flexible, how you create and manage your Ansible playbook is entirely up to you, but here is an example for a Drupal project:

```yaml
---
- hosts: localhost
  vars_files:
    - vars/common.yml
  tasks:
    - ansible.builtin.import_role:
        name: _init
    - name: Create needed public directories
      ansible.builtin.file:
        path: /var/www/shared/{project_name}_ddev_default_public_files
        state: directory
    - name: Create needed private directories
      ansible.builtin.file:
        path: /var/www/shared/{project_name}_ddev_default_private_files
        state: directory
    - ansible.builtin.import_role:
        name: composer
    - ansible.builtin.import_role:
        name: database_backup
    - ansible.builtin.import_role:
        name: config_generate
    - ansible.builtin.import_role:
        name: cache_clear/cache_clear-opcache
    - ansible.builtin.import_role:
        name: database_apply
    - ansible.builtin.import_role:
        name: npm
    - ansible.builtin.import_role:
        name: cache_clear/cache_clear-drupal8
    - ansible.builtin.import_role:
        name: cron/cron_drupal8
    - ansible.builtin.import_role:
        name: _exit
```

And this is the file loaded in by the `vars_files` list, from the `./deploy/vars` directory of the code repository:

```yaml
---
# common.yml variables
# See ~/ce-deploy/config/hosts/group_vars/all in the web container for ddev defaults.
# You can override them here if necessary.
project_name: example
project_type: drupal8
webroot: web
mysql_backup:
  databases:
    - database: "{{ (project_name + '_' + build_type) | regex_replace('-', '_') }}" # avoid hyphens in MySQL database names
      user: "{{ (project_name + '_' + build_type) | truncate(32, true, '', 0) }}" # 32 char limit
      credentials_file: "/home/{{ _ce_provision_username }}/.my.cnf"
  keep: 0
  credentials_handling: manual
  handling: none
  databases:
    - database: db
      user: root
      credentials_file: "/home/{{ ansible_user_id }}/.my.cnf"
deploy_code:
  keep: 0
  perms_fix_path: "web/sites/default"
drupal:
  drush_verbose_output: true
  sites:
    - folder: "default"
      public_files: "sites/default/files"
      config_import_command: "cim"
      config_sync_directory: "config/sync"
      sanitize_command: "sql-sanitize"
      install_command: "-y si"
      cron:
        - minute: "*/{{ 10 | random(start=1) }}"
          job: cron
cachetool:
  adapter: "--fcgi=/var/run/php-fpm.sock"
```

### Local Overrides With External Deployments

If you are already using ce-deploy on your project then you will have an existing common.yml file that you probably want to keep intact as this will set up many of the settings for your dev/stage/prod deployments. To keep those settings you need to include a `./deploy/vars/ddev.yml` file and override them where needed.

```yaml
---
# ddev.yml deploy variables, overriding the common.yml settings.
# See ~/ce-deploy/config/hosts/group_vars/all for ce-deploy defaults.
deploy_base_path: "/var/www"
deploy_assets_base_path: "/var/www/shared"

# If you have overridden the *_user variables to non-standard values due to
# your server set up, you will need to explicitly override them to use the ddev
# user's username.
ansible_user: "{{ lookup('ansible.builtin.env','DDEV_USER') }}"
deploy_user: "{{ ansible_user }}"
www_user: "{{ ansible_user }}"

mysql_backup:
  databases:
    - database: "{{ (project_name + '_' + build_type) | regex_replace('-', '_') }}" # avoid hyphens in MySQL database names
      user: "{{ (project_name + '_' + build_type) | truncate(32, true, '', 0) }}" # 32 char limit
      credentials_file: "/home/{{ _ce_provision_username }}/.my.cnf"
  keep: 0
maintenance_mode:
  mode: drupal-core
deploy_code:
  keep: 0
  perms_fix_path: "web/sites/default"
drupal:
  drush_verbose_output: true
  sites:
    - folder: "default"
      public_files: "sites/default/files"
      config_import_command: ""
      config_sync_directory: "config/sync"
      sanitize_command: "sql-sanitize"
      install_command: ""
      cron:
        - minute: "*/{{ 10 | random(start=1) }}"
          job: cron
cachetool:
  adapter: "--fcgi=/var/run/php-fpm.sock"
```

This will inherit settings like project_name and project_type so there is no need to define those in this file.

This is then included in your `deploy-ddev.yml` in the following way.

```yaml
  vars_files:
    - vars/common.yml
    - vars/ddev.yml
```

Make sure these are in the correct order. You want the common.yml file _first_, followed by the ddev.yml file to override variables in the common.yml file.

## `ddev get-db` Command

Fetch a database dump from a remote server and import it into your local DDEV environment.

**Note:** This command runs on your **host machine** (not inside the DDEV container) so it can access your SSH agent and keys.

### Quick Start

```bash
# First time setup - interactive prompts (will offer to save to config)
ddev get-db

# With all parameters
ddev get-db --project myproject --host dev.example.com --environment dev --user deploy

# Using saved configuration (subsequent runs)
ddev get-db --environment prod

# Verbose output for debugging
ddev get-db -p myproject -e stage --verbose

# Keep remote dump file
ddev get-db --project myproject --keep-remote

# Skip cache clearing
ddev get-db --project myproject --no-cache-clear
```

### Configuration

The command will automatically offer to save your project name and host to the config after the first run. You can also manually add settings to `.ddev/config.yaml`:

```yaml
get_db:
  project: myproject
  mysql_credentials_path: "/home/deploy/.mysql.creds"  # Optional default
  environments:
    dev:
      host: dev.example.com
      user: deploy
      remote_path: "/home/deploy/deploy/myproject_dev/live.myproject_dev"
      mysql_credentials_path: "/home/deploy/.mysql.creds"  # Optional override
      database: myproject_dev  # Optional (auto-detected if not set)
    stage:
      host: stage.example.com
      user: deploy
      remote_path: "/home/deploy/deploy/myproject_stage/live.myproject_stage"
    prod:
      host: prod.example.com
      user: deploy
      remote_path: "/home/deploy/deploy/myproject_prod/live.myproject_prod"
```

### Options

| Option | Alias | Default | Description |
|--------|-------|---------|-------------|
| `--project` | `-p` | (required) | Project name |
| `--host` | `-h` | (from config) | Remote server hostname |
| `--user` | `-u` | `deploy` | Remote SSH user |
| `--environment` | `-e`, `--env` | `dev` | Environment name |
| `--mysql-creds` | | `/home/{user}/.mysql.creds` | MySQL credentials file on remote |
| `--database` | | (auto-detect) | Database name to dump |
| `--no-cache-clear` | | false | Skip cache clearing |
| `--no-gzip` | | false | Skip gzip compression |
| `--keep-remote` | | false | Keep remote dump file after download |
| `--verbose` | `-v` | false | Verbose output for debugging |
| `--dry-run` | | false | Show what would be executed without running |

### How It Works

1. **Configuration**: Loads settings from `.ddev/config.yaml` or prompts for missing values (offers to save for future use)
2. **SSH Connection**: Connects to remote server using your local SSH agent
3. **User Switch**: Uses `sudo` to switch to the specified user on remote (default: deploy)
4. **Navigate**: Changes to the remote project directory
5. **Tooling Check**: Verifies drush (Drupal) or WP-CLI (WordPress) is installed, installs if needed
6. **Database Detection**: Automatically detects database name from settings files
7. **Create Dump**: Creates an SQL dump, then compresses it with gzip (separate steps for reliability)
8. **Download**: Copies the dump file to your local machine via SCP
9. **Import**: Imports the database into your local DDEV environment (auto-detects .sql.gz)
10. **Cache Clear**: Clears application cache (Drupal, WordPress, Laravel, Symfony, etc.)
11. **Cleanup**: Removes temporary dump files (unless `--keep-remote` specified)

### MySQL Credentials

The remote server should have a MySQL credentials file at `/home/{user}/.mysql.creds`:

```ini
[client]
user=dbuser
password=secret
host=localhost
```

Override the default path with `--mysql-creds /path/to/creds`.

### Supported Project Types

Automatic cache clearing is supported for:

| Project Type | Cache Clear Method |
|-------------|-------------------|
| Drupal 8-11 | `drush cr` |
| Drupal 7 | `drush cc all` |
| Drupal 6 | `drush cc all` |
| WordPress | `wp cache flush` |
| Laravel | `artisan cache:clear`, `config:clear`, `route:clear`, `view:clear` |
| Symfony | `console cache:clear` |
| Magento 2 | Framework-specific commands |
| Craft CMS | Framework-specific commands |
| TYPO3 | Framework-specific commands |

For unknown project types, cache clearing is skipped with a warning.

### Hooks

Add a `.ddev/hooks/post-get-db` script to execute custom commands after database import:

```bash
#!/bin/bash
echo "Running post-get-db tasks..."
ddev exec drush updatedb -y
ddev exec drush cim -y
```

### Security Notes

- SSH authentication uses your local SSH agent only (no passwords)
- MySQL credentials are stored on the remote server, not locally
- Database dumps are compressed and stored in `/tmp/` with restricted permissions
- Temporary files are cleaned up automatically after import

## Troubleshooting
Here are some issues to watch out for. Please note, although the `ddev get-db` command theoretically works for different kinds of application, to date it has only really been tested with Drupal.

### Drupal files directory
If you're deploying a Drupal application in DDEV with `ce-deploy` using a `drupal` project type can cause problems. When the DDEV project type is `drupal` it always wants to make the `sites/default/files` directory when you run `ddev start`. This clashes with `ce-deploy`, which always wants that same directory to be a symbolink link. Until we fix that you can either use project type of `php` and forego the `drush` integration from the CLI or manually remove `sites/default/files` after `ddev start` and before running `ddev deploy`.

Another possibility is to start the project with a type of `php` so that DDEV does not try to install Drupal, run `ddev deploy` and then switch later to a `drupal` project with `ddev config --project-type drupal` to have `drush` support. It will give you an error about the files directory on start, but you can ignore it.

### Drupal config import
If you are running config import to Drupal with `ce-deploy` you might see this error:

```
Site UUID in source storage does not match the target storage.
```

If so, go to your config sync directory and look in the `system.site.yml` file. Copy the `uuid` value in that file and then run this command:

```sh
ddev drush cset "system.site" uuid "<your-uuid>"
```

Where `<your-uuid>` is the value you copied from the `system.site.yml` file.

### SSH Connection Issues
```bash
# Check SSH agent has keys (run on your host)
ssh-add -l

# Add key if needed
ssh-add ~/.ssh/id_ed25519

# Test connection manually
ssh -A deploy@dev.example.com
```

**Note:** The `get-db` command runs on your **host machine**, not inside the DDEV container. This allows it to access your local SSH agent and keys. If you're getting "No SSH keys found" errors, make sure you've added your key to the SSH agent on your host.

### Database Detection Fails
```bash
# Specify database name explicitly
ddev get-db --project myproject --database mydb
```

### Verbose Debugging
```bash
# See detailed output
ddev get-db --project myproject --verbose

# Dry run to see commands
ddev get-db --project myproject --dry-run
```
