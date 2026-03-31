# ddev-ce-deploy

This is a DDEV add-on that prepares any project to use the [DDEV local development tool](https://ddev.com/) combined with [`ce-deploy`](https://gitlab.com/code-enigma/ce-deploy), the Ansible-based code deployment tool by [Code Enigma](https://www.codeenigma.com/).

## Installation

Install this add-on with:

```bash
ddev add-on get code-enigma/ddev-ce-deploy
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