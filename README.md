# WP Push Remote

A bash script to push WordPress sites from a SOURCE (LOCAL) server to a REMOTE server using WP-CLI and rsync. Works on Ubuntu 22.04 LTS and higher.

## Features

- 🚀 **One-Time Configuration**: Configure once with `--config`, settings saved automatically
- 🎯 **Smart Auto-Detection**: URLs and table prefixes detected via WP-CLI
- 📁 **Custom Exclusions**: Space-delimited exclusion lists via `-e` flag
- 🔌 **Plugin Installation**: Install multiple plugins with `--install-plugins "plugin1 plugin2"`
- 🔄 **Database Migration**: Automatic export, transfer, import, and search-replace
- 🧹 **Optional SQL Sanitizing**: Use `-f` when needed to strip privileged SQL statements before import
- 🔐 **Modern SSH Keys**: Ed25519 key generation for better security
- ⚙️ **Multiple Modes**: Interactive, unattended, and files-only modes
- 🔄 **Table Prefix Sync**: Automatic detection and synchronization of mismatched prefixes

## Requirements

- **Operating System**: Ubuntu 22.04 LTS or higher (both source and remote)
- **WP-CLI**: Must be installed on both source and remote servers
- **SSH Access**: SSH access to the remote server
- **rsync**: For file synchronization (usually pre-installed)
- **openssh-client**: For SSH connectivity (usually pre-installed)

### Installing Requirements on Ubuntu 22.04+

```bash
# Install openssh-client and rsync if not present
sudo apt update
sudo apt install openssh-client rsync

# Install WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

# Verify installation
wp --info
```

## Installation

Clone the repository as root or with sudo to `/opt/`:

```bash
sudo git clone https://github.com/WPNET/wp-push-remote.git /opt/wp-push-remote
cd /opt/wp-push-remote
sudo chmod +x wp-push-remote.sh
```

Install to site user directories:

```bash
sudo /opt/wp-push-remote/wp-push-remote.sh --install-for-user
# Select from numbered list of sites in /sites/*/files/
# Script installed as /sites/{domain}/.local/bin/wp-push-remote
```

**Important:** After installation, the script must ONLY be run as the site user, never as root. The push operations will not work correctly if run as root.

## Usage

Switch to the site user and run from the site directory:

```bash
# As the site user (not root)
cd /sites/yourdomain.com
./.local/bin/wp-push-remote --config    # First time: configure settings
./.local/bin/wp-push-remote              # Push to remote server
```

### Display Help

```bash
./.local/bin/wp-push-remote --help
# or
./.local/bin/wp-push-remote -h
```

### Command-Line Options

#### General Options

- `-h, --help` - Show help message
- `-u, --unattended` - Run in unattended mode (no prompts)
- `-i, --install-for-user` - Install script to a user's site directory (skips push operation)
- `-c, --config` - Configure source/remote settings (saves to `~/.wp-push-remote.conf`)
- `-D, --del-ssh-key` - Delete SSH key pairs for remote user (skips push operation)
- `-f, --filter-sql` - Filter SQL dump to remove privileged statements before import (slower export)
- `-p, --install-plugins "LIST"` - Install plugins (space-delimited list)
- `-r, --remote-cmds "CMD"` - Run custom commands on remote (quote the commands)

#### Exclusions

- `-e, --exclude "LIST"` - Space-delimited list of paths to exclude
  ```bash
  ./wp-push-remote.sh -e "uploads .git .maintenance"
  ```

#### Option Flags

Boolean flags (presence = enabled):

- `--search-replace` - Run wp search-replace on database (default: yes)
- `--no-search-replace` - Skip wp search-replace
- `--files-only` - Skip all database operations
- `--no-db-import` - Don't import database on remote
- `--exclude-wpconfig` - Exclude wp-config.php from rsync (default: yes)
- `--no-exclude-wpconfig` - Include wp-config.php in sync
- `--disable-wp-debug` - Temporarily disable WP_DEBUG during push
- `--all-tables-with-prefix` - Use --all-tables-with-prefix option for wp search-replace commands (default: no)

### Examples

```bash
# Configure settings (first time)
./.local/bin/wp-push-remote --config

# Push to remote (uses saved config)
./.local/bin/wp-push-remote

# Install plugins on remote
./.local/bin/wp-push-remote --install-plugins "woocommerce contact-form-7"

# Files only (no database)
./.local/bin/wp-push-remote --files-only

# Unattended mode with exclusions
./.local/bin/wp-push-remote -u -e "uploads cache .git"

# Skip search-replace
./.local/bin/wp-push-remote --no-search-replace

# Run custom commands on remote
./.local/bin/wp-push-remote -r "wp plugin update --all"

# Delete SSH key pairs
./.local/bin/wp-push-remote --del-ssh-key

# Enable SQL filtering for restrictive MySQL destination permissions
./.local/bin/wp-push-remote -f

# Combined options
./.local/bin/wp-push-remote -f --install-plugins "akismet jetpack" -e "uploads cache"
```

## SSH Key Management

The script automatically generates SSH keys for secure authentication. After completing a push operation, you can delete these keys if desired.

### Deleting SSH Keys

To delete SSH key pairs:
```bash
./.local/bin/wp-push-remote --del-ssh-key
```

This will:
- Search for all SSH keys matching the configured remote user (Ed25519 and RSA)
- Display found key pairs with their locations
- Delete both private and public keys
- Remind you to manually remove the public key from the remote server's `~/.ssh/authorized_keys` file

**Important**: You must manually remove the public key from the remote server after deletion.

## Configuration

### Persistent Configuration

Run `--config` once to save your settings to `~/.wp-push-remote.conf`. The configuration is automatically loaded on subsequent runs.

### What Gets Configured

When you run `./.local/bin/wp-push-remote --config`, you'll be prompted for:
- **Source path prefix**: e.g., `/sites/example.com/`
- **Source webroot**: e.g., `files` or `files/public_html`
- **Remote IP/hostname**: e.g., `192.168.1.100` or `staging.example.com`
- **Remote user**: SSH username on remote server
- **Remote path prefix**: e.g., `/sites/staging.example.com/`
- **Remote webroot**: e.g., `files` or `files/htdocs`

### Auto-Detection

The script automatically detects:
- **WordPress URLs**: Via `wp option get siteurl` on both sites
- **Table prefixes**: Via `wp db prefix` command (WP-CLI best practice)
- **File paths**: Derived from your configured paths

### Smart Defaults

- Path structure defaults to `/sites/{domain}/files` pattern
- Press Enter to accept defaults shown in [brackets]
- Previous values remembered for easy updates

### Default Exclusions

These paths are excluded by default:
- `.git`
- `.maintenance`
- `wp-content/cache`
- `wp-content/uploads/wp-migrate-db`
- `/wp-content/updraft`
- `.user.ini`
- `wp-config.php` (unless `--no-exclude-wpconfig` is used)

## Key Features Explained

### Table Prefix Synchronization

The script uses `wp db prefix` (WP-CLI best practice) to detect table prefixes on both sites. If they differ:
1. Warns you about the mismatch
2. Prompts for confirmation to synchronize
3. Resets remote database: `wp db reset --yes`
4. Sets matching prefix: `wp config set table_prefix`
5. Continues with normal database import

In unattended mode, mismatches are logged but no automatic changes are made (safer).

### Plugin Installation

Install multiple plugins on the remote with a single command:
```bash
./.local/bin/wp-push-remote --install-plugins "plugin-slug1 plugin-slug2 plugin-slug3"
```

Plugins are installed after database operations and cache is flushed automatically.

### SSH Key Management

The script manages SSH keys automatically:
- Checks for existing key: `~/.ssh/id_ed25519_remote_{user}`
- Falls back to RSA key if Ed25519 not found
- Generates new Ed25519 key if none exists (in interactive mode)
- Tests connection before proceeding
- Sets proper permissions (600) automatically

## Workflow

1. **Configuration**: Load saved config or prompt with `--config`
2. **Auto-Detection**: Detect URLs and table prefixes via WP-CLI
3. **SSH Setup**: Use existing or generate Ed25519 SSH key
4. **Connection Test**: Verify SSH access (optional in interactive mode)
5. **Table Prefix Check**: Compare and sync if different (with confirmation)
6. **Database Export**: Export source database (unless `--files-only`)
7. **Optional SQL Filter**: If `-f` is set, strip privileged statements from dump (adds processing time)
8. **File Sync**: Rsync files to remote with exclusions
9. **Database Import**: Import database on remote
10. **Search-Replace**: Update URLs and paths (unless `--no-search-replace`)
11. **Plugin Installation**: Install plugins if specified via `--install-plugins`
12. **Cache Flush**: Single cache flush after all operations
13. **Cleanup**: Remove temporary files

## Troubleshooting

### SSH Connection Issues

If you get a password prompt when connecting to the remote:
1. Ensure the public key is added to `~/.ssh/authorized_keys` on the remote server
2. Check SSH key permissions: `chmod 600 ~/.ssh/id_rsa_remote_*`
3. Verify the remote user has SSH access

### WP-CLI Not Found

Ensure WP-CLI is installed and accessible:
```bash
wp --info

### MySQL Privilege Error During Import (ERROR 1227)

If remote import fails with privilege errors (for example SUPER, SYSTEM_VARIABLES_ADMIN, or SESSION_VARIABLES_ADMIN), run with SQL filtering enabled:

```bash
./.local/bin/wp-push-remote -f
```

This strips privileged statements (such as GTID/session/global assignments) from the dump before import. It is disabled by default because it adds extra processing time.
```

If not installed, follow the [WP-CLI installation guide](https://wp-cli.org/#installing).

### Database Import Fails

1. Verify database credentials in remote wp-config.php
2. Ensure sufficient disk space on remote server

### Rsync Errors

1. Verify source and remote paths are correct
2. Check SSH connectivity
3. Ensure sufficient permissions on both source and remote

## Security Considerations

- **wp-config.php**: Excluded by default to prevent overwriting remote configuration
- **SSH Keys**: Ed25519 keys (preferred) for better security on Ubuntu 22.04+
- **Database Cleanup**: Temporary SQL files cleaned up after import
- **Unattended Mode**: Use cautiously - skips confirmations
- **Table Prefix Sync**: Requires confirmation before resetting remote database

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This script is provided as-is for use in WordPress deployments.

## Author

**gb@wpnet.nz**

## Support

For issues, questions, or suggestions, please open an issue on GitHub.

## Notes

- This script is optimized for Ubuntu 22.04 LTS and higher
- It uses modern bash features (5.0+) and Ubuntu-specific tools
- SSH keys are generated using Ed25519 algorithm for better performance
- The script validates the environment before execution
