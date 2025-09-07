# Homelab Ansible Automation

Ansible-based automation for managing your homelab infrastructure, including version management for Terraform services and host-level service setup.

## 🏗️ Available Automations

### [VERSION] Version Management (`upgrade.yml`)
Automated version checking and upgrading for your homelab services using Terraform.

### [TERMINAL] ttyd Web Terminal (`ttyd-setup.yml`)  
Web-based terminal access to your Mac host system for direct system interaction.

---

## [TERMINAL] ttyd Web Terminal Setup

### Quick Setup
```bash
cd automation
ansible-playbook ttyd-setup.yml
```

### What it does:
- [x] Installs ttyd via Homebrew
- [x] Creates launchd service for auto-start  
- [x] Configures localhost-only access (127.0.0.1:7681)
- [x] Enables writable terminal with full Mac system access
- [x] Sets up proper service management

### Access Your Terminal
- **URL**: http://127.0.0.1:7681
- **Features**: Full Mac terminal access, perfect for Claude code usage
- **Security**: Localhost-only, no external exposure

### Service Management
```bash
# Check status
launchctl list | grep ttyd

# Stop/Start service  
launchctl stop com.homelab.ttyd
launchctl start com.homelab.ttyd

# View logs
tail -f /tmp/ttyd.log
tail -f /tmp/ttyd.error.log

# Reload after config changes
launchctl unload ~/Library/LaunchAgents/com.homelab.ttyd.plist && \
launchctl load ~/Library/LaunchAgents/com.homelab.ttyd.plist
```

---

## [VERSION] Version Management

## Features

- [SEARCH] **Automated Version Discovery**: Finds current and latest versions for all services
- [TABLE] **Beautiful Table Display**: Clear comparison of current vs available versions  
- [TARGET] **Selective Upgrades**: Upgrade individual services or all at once
- [SYNC] **Terraform Integration**: Updates Terraform modules and applies changes safely
- [BOLT] **Zero Configuration**: Works out of the box with your existing setup

## Quick Start

### Initial Setup (One-time)

```bash
cd automation
./upgrade setup
```

This installs required Ansible collections (`kubernetes.core`, `community.docker`).

### Check Service Versions

```bash
./upgrade check
# or just
./upgrade
```

**Example Output:**
```
╔══════════════════════════════════════════════════════════════════════════════════╗
║                      [HOME] HOMELAB SERVICES VERSION STATUS                     ║
╠════════════════╦══════════╦═══════════════╦═══════════════╦═══════════════════╣
║    SERVICE     ║   TYPE   ║    CURRENT    ║    LATEST     ║      STATUS       ║
╠════════════════╬══════════╬═══════════════╬═══════════════╬═══════════════════╣
║ open-webui     ║ helm     ║ 7.2.0         ║ 7.3.0         ║ [UP] UPGRADE_AVAIL║
║ flowise        ║ helm     ║ 5.1.1         ║ 6.0.0         ║ [UP] UPGRADE_AVAIL║
║ homepage       ║ helm     ║ 2.1.0         ║ 2.1.0         ║ [OK] UP_TO_DATE   ║
║ postgresql     ║ helm_oci ║ 16.7.21       ║ OCI_REGISTRY  ║ [?] MANUAL_CHECK  ║
║ n8n            ║ helm_oci ║ 1.0.10        ║ OCI_REGISTRY  ║ [?] MANUAL_CHECK  ║
║ calibre-web    ║ docker   ║ latest        ║ latest        ║ [UP] PULL_LATEST  ║
╚════════════════╩══════════╩═══════════════╩═══════════════╩═══════════════════╝
```

### Upgrade Services

```bash
# Upgrade a specific service
./upgrade open-webui

# Upgrade all services with available updates
./upgrade all
```

## How It Works

1. **Service Discovery**: Scans your Kubernetes cluster using `helm list`
2. **Version Lookup**: Queries Helm repositories for latest chart versions
3. **Comparison**: Creates a comprehensive comparison table
4. **Terraform Integration**: Updates version constraints in Terraform modules
5. **Safe Deployment**: Uses `terraform plan` → confirm → `terraform apply`

## Status Guide

| Status | Description | Action Required |
|--------|-------------|-----------------|
| [OK] **UP_TO_DATE** | Running latest version | None |
| [UP] **UPGRADE_AVAILABLE** | New version available | Can upgrade automatically |
| [?] **MANUAL_CHECK** | OCI registry chart | Check manually, update Terraform |
| [X] **NOT_DEPLOYED** | Service not running | Check Terraform deployment |
| [UP] **PULL_LATEST** | Docker latest tag | Will pull fresh image |

## Supported Services

| Service | Type | Repository | Auto-Upgrade |
|---------|------|------------|--------------|
| **open-webui** | Helm | helm.openwebui.com | [x] Yes |
| **flowise** | Helm | cowboysysop.github.io | [x] Yes |
| **homepage** | Helm | jameswynn.github.io | [x] Yes |
| **postgresql** | Helm (OCI) | registry-1.docker.io/bitnami | [?] Manual |
| **n8n** | Helm (OCI) | 8gears.container-registry.com | [?] Manual |
| **calibre-web** | Docker | lscr.io/linuxserver | [x] Yes |
| **metrics-server** | Helm | kubernetes-sigs.github.io | [x] Yes |

## Project Structure

```
automation/
├── upgrade.yml          # Main Ansible playbook
├── upgrade              # Wrapper script
├── ansible.cfg          # Ansible configuration
├── inventory.yml        # Localhost inventory
├── requirements.yml     # Required collections
├── group_vars/
│   └── all.yml         # Global variables
└── README.md           # This file
```

## Advanced Usage

### Direct Ansible Commands

```bash
# Check versions only
ansible-playbook upgrade.yml --tags check

# Upgrade specific service
ansible-playbook upgrade.yml --tags upgrade -e service=open-webui

# Upgrade all services
ansible-playbook upgrade.yml --tags upgrade -e upgrade_all=true

# Dry run (see what would change)
ansible-playbook upgrade.yml --check --diff
```

### Manual OCI Registry Updates

For services using OCI registries (PostgreSQL, n8n):

1. Check latest versions manually:
   - PostgreSQL: https://hub.docker.com/r/bitnami/postgresql
   - n8n: https://github.com/n8n-io/n8n/releases

2. Update Terraform module version
3. Apply: `terraform apply`

### CI/CD Integration

```yaml
# GitHub Actions example
name: Homelab Updates
on:
  schedule:
    - cron: '0 9 * * 1'  # Weekly Monday 9 AM

jobs:
  check-updates:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Ansible
        run: pip install ansible kubernetes docker
      - name: Install collections
        run: cd automation && ansible-galaxy collection install -r requirements.yml
      - name: Check versions
        run: cd automation && ./upgrade check
      - name: Upgrade services
        run: cd automation && ./upgrade all
```

## Safety Features

- **Confirmation Prompts**: Always asks before applying changes
- **Terraform Plan Review**: Shows exactly what will change
- **Targeted Updates**: Only affects the specific service being upgraded
- **Idempotent Operations**: Safe to run multiple times
- **Rollback Ready**: Standard Terraform/Helm rollback procedures apply

## Troubleshooting

### Ansible Collections Missing
```bash
./upgrade setup
# or manually:
ansible-galaxy collection install kubernetes.core community.docker
```

### Helm Repository Issues
```bash
helm repo update
helm repo list
```

### Terraform Errors
```bash
cd ..
terraform refresh
terraform plan
```

### Kubernetes Connection
```bash
kubectl config current-context
kubectl get pods -n homelab
```

## Examples

```bash
# Daily version check
./upgrade

# Weekly maintenance
./upgrade all

# Specific service update
./upgrade open-webui

# Check what would be upgraded
ansible-playbook upgrade.yml --tags check

# Upgrade with verbose output
ansible-playbook upgrade.yml --tags upgrade -e service=flowise -v
```

## Best Practices

1. **Regular Checks**: Run `./upgrade` weekly to stay informed
2. **Staged Upgrades**: Upgrade one service at a time for critical systems
3. **Backup First**: Take backups before major version upgrades
4. **Test Locally**: Use `terraform plan` to review changes
5. **Monitor**: Check service health after upgrades

---

**🏠 Happy Homelabbing with Ansible!**