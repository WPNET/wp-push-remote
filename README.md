# WP Push Remote

A bash script to push WordPress sites from a SOURCE (LOCAL) server to a REMOTE server using WP-CLI and rsync. Works on Ubuntu 22.04 LTS and higher.

## Features

- 🚀 **One-Time Configuration**: Configure once with `--config`, settings saved automatically
- 🎯 **Smart Auto-Detection**: URLs and table prefixes detected via WP-CLI
- 📁 **Custom Exclusions**: Space-delimited exclusion lists via `-e` flag
- 🔌 **Plugin Installation**: Install multiple plugins with `--install-plugins "plugin1 plugin2"`
- 🔄 **Database Migration**: Automatic export, transfer, import, and search-replace
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

### Recommended: System-Wide Installation

For best results, clone the repository as root or a sudo user to a system location like `/opt/`:

```bash
# Clone as root or with sudo
sudo git clone https://github.com/WPNET/wp-push-remote.git /opt/wp-push-remote
cd /opt/wp-push-remote
sudo chmod +x wp-push-remote.sh
```

Then install the script into individual site user directories:

```bash
# Install to a site user's directory
sudo /opt/wp-push-remote/wp-push-remote.sh --install-for-user
# Select from numbered list of available sites in /sites/*/files/
# Script will be installed as /sites/{domain}/wp-push-remote
```

**Benefits of this approach:**
- Central script location for easy updates
- Proper permissions for all site directories
- Each site user gets their own copy
- Installed copies cannot recursively install (disabled by design)

### Alternative: User Installation

If you prefer to run as a regular user:

```bash
git clone https://github.com/WPNET/wp-push-remote.git
cd wp-push-remote
chmod +x wp-push-remote.sh
```

**Note:** You may need sudo privileges for the `--install-for-user` option to set proper ownership on site directories.

## Usage

### Quick Start

**If installed system-wide (recommended):**

```bash
# As root/sudo, install to a site user's directory
sudo /opt/wp-push-remote/wp-push-remote.sh --install-for-user

# Then run from the site user's directory
cd /sites/yourdomain.com
./wp-push-remote --config    # First time: configure settings
./wp-push-remote              # Subsequent runs: use saved config
```

**If running from cloned repository:**

```bash
# First time setup
./wp-push-remote.sh --config
# Configure source/remote paths once - settings saved automatically
# URLs and table prefixes detected via WP-CLI

# Subsequent runs
./wp-push-remote.sh
# Uses saved configuration - no re-entry needed!
```

### Display Help

```bash
./wp-push-remote --help
# or
./wp-push-remote -h
```

### Command-Line Options

#### General Options

- `-h, --help` - Show help message
- `-u, --unattended` - Run in unattended mode (no prompts)
- `-i, --install-for-user` - Install script to a user's site directory (skips push operation)
- `-c, --config` - Configure source/remote settings (saves to `~/.wp-push-remote.conf`)
- `-D, --del-ssh-key` - Delete SSH key pairs for remote user (skips push operation)
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

#### First Time Configuration
```bash
./wp-push-remote --config
# Prompts for source/remote paths with smart defaults
# Saves to ~/.wp-push-remote.conf automatically
```

#### Run with Saved Configuration
```bash
./wp-push-remote
# Uses saved settings - ready to go!
```

#### Install Plugins on Remote
```bash
./wp-push-remote --install-plugins "woocommerce contact-form-7 wordpress-seo"
```

#### Files Only (No Database)
```bash
./wp-push-remote --files-only
```

#### Unattended Mode with Exclusions
```bash
./wp-push-remote -u -e "uploads cache .git"
```

#### Skip Search-Replace
```bash
./wp-push-remote --no-search-replace
```

#### Use All Tables With Prefix for Search-Replace
```bash
./wp-push-remote --all-tables-with-prefix
```

#### Run Custom Commands on Remote
```bash
./wp-push-remote --remote-cmds "wp theme install twentytwenty"
# or with short option
./wp-push-remote -r "wp plugin update --all"
```

#### Delete SSH Key Pairs
```bash
./wp-push-remote --del-ssh-key
# Deletes SSH key pairs for the configured remote user
# Shows details of deleted keys
# Reminds you to manually remove public key from remote server
```

#### Install Script for a Site User

Best practice: Clone to `/opt/` as root, then install to site directories:

```bash
# From system-wide installation
sudo /opt/wp-push-remote/wp-push-remote.sh --install-for-user

# Or from local clone
./wp-push-remote.sh --install-for-user

# Interactive prompt:
# 1. /sites/example.com
# 2. /sites/mysite.org
# 3. /sites/another.com
# Enter number: 1

# Result:
# - Script copied to /sites/example.com/wp-push-remote
# - Ownership set to site user
# - Executable permissions set
# - --install-for-user option disabled in the copy
```

#### Combined Options
```bash
./wp-push-remote --install-plugins "akismet jetpack" -e "uploads cache"
```

## SSH Key Management

The script automatically generates SSH keys for secure authentication. After completing a push operation, you can delete these keys if desired.

### Deleting SSH Keys

To delete SSH key pairs:
```bash
./wp-push-remote --del-ssh-key
```

This will:
- Search for all SSH keys matching the configured remote user (Ed25519 and RSA)
- Display found key pairs with their locations
- Delete both private and public keys
- Remind you to manually remove the public key from the remote server's `~/.ssh/authorized_keys` file

**Important**: You must manually remove the public key from the remote server after deletion.

## Installation Workflow

### System-Wide Setup (Recommended)

This is the recommended approach for managing multiple WordPress sites:

1. **Clone to a system location as root:**
   ```bash
   sudo git clone https://github.com/WPNET/wp-push-remote.git /opt/wp-push-remote
   cd /opt/wp-push-remote
   sudo chmod +x wp-push-remote.sh
   ```

2. **Install to site user directories:**
   ```bash
   sudo /opt/wp-push-remote/wp-push-remote.sh --install-for-user
   # Select site from numbered list
   ```

3. **Configure and run from site directory:**
   ```bash
   # Switch to site user or directory
   cd /sites/yourdomain.com
   ./wp-push-remote --config    # Configure once
   ./wp-push-remote              # Run push operations
   ```

**Why this approach works best:**
- Single source repository for updates
- Root/sudo privileges handle ownership correctly
- Each site user gets an isolated copy
- Installed copies cannot recursively install

### Per-User Setup

If you don't have root access or prefer user-level installation:

```bash
git clone https://github.com/WPNET/wp-push-remote.git ~/wp-push-remote
cd ~/wp-push-remote
chmod +x wp-push-remote.sh
./wp-push-remote.sh --config
```

**Note:** The `--install-for-user` option may require sudo for setting ownership.

## Configuration

### Persistent Configuration

Run `--config` once to save your settings to `~/.wp-push-remote.conf`. The configuration is automatically loaded on subsequent runs.

### What Gets Configured

When you run `./wp-push-remote --config`, you'll be prompted for:
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
./wp-push-remote --install-plugins "plugin-slug1 plugin-slug2 plugin-slug3"
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
7. **File Sync**: Rsync files to remote with exclusions
8. **Database Import**: Import database on remote
9. **Search-Replace**: Update URLs and paths (unless `--no-search-replace`)
10. **Plugin Installation**: Install plugins if specified via `--install-plugins`
11. **Cache Flush**: Single cache flush after all operations
12. **Cleanup**: Remove temporary files

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
