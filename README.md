# WP Push Remote

A powerful bash script to push WordPress sites from a SOURCE server to a REMOTE server using WP-CLI and rsync. Optimized for Ubuntu 24.04 LTS and higher.

## Features

- 🚀 **One-Time Configuration**: Configure once with `--config`, settings saved automatically
- 🎯 **Smart Auto-Detection**: URLs and table prefixes detected via WP-CLI
- 📁 **Custom Exclusions**: Space-delimited exclusion lists via `-e` flag
- 🔌 **Plugin Installation**: Install multiple plugins with `--install-plugins "plugin1 plugin2"`
- 🔄 **Database Migration**: Automatic export, transfer, import, and search-replace
- 🔐 **Modern SSH Keys**: Ed25519 key generation for better security
- ⚙️ **Multiple Modes**: Interactive, unattended, and files-only modes
- 🔄 **Table Prefix Sync**: Automatic detection and synchronization of mismatched prefixes
- 📝 **Systemd Integration**: Automatic logging to systemd journal

## Requirements

- **Operating System**: Ubuntu 24.04 LTS or higher (both source and remote)
- **Bash**: Version 5.1+ (included in Ubuntu 24.04)
- **WP-CLI**: Must be installed on both source and remote servers
- **wp-cli.yml**: Configured in home directory with correct WP installation path
- **SSH Access**: SSH access to the remote server
- **rsync**: For file synchronization (usually pre-installed)
- **openssh-client**: For SSH connectivity (usually pre-installed)

### Installing Requirements on Ubuntu 24.04

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

1. Clone this repository or download the script:
   ```bash
   git clone https://github.com/WPNET/wp-push-remote.git
   cd wp-push-remote
   ```

2. Make the script executable:
   ```bash
   chmod +x wp-push-remote.sh
   ```

3. Edit default configuration values in the script (optional):
   ```bash
   nano wp-push-remote.sh
   ```

## Usage

### Quick Start

**First time setup:**
```bash
./wp-push-remote.sh --config
# Configure source/remote paths once - settings saved automatically
# URLs and table prefixes detected via WP-CLI
```

**Subsequent runs:**
```bash
./wp-push-remote.sh
# Uses saved configuration - no re-entry needed!
```

### Display Help

```bash
./wp-push-remote.sh --help
# or
./wp-push-remote.sh -h
```

### Command-Line Options

#### General Options

- `-h, --help` - Show help message
- `-u, --unattended` - Run in unattended mode (no prompts)
- `-i, --interactive` - Run in interactive mode (default)
- `-c, --config` - Configure source/remote settings (saves to `~/.wp-push-remote.conf`)
- `-D, --del-ssh-key` - Delete SSH key pairs for remote user (skips push operation)

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
- `--install-plugins "LIST"` - Install plugins (space-delimited list)
- `--run-remote-commands` - Run custom commands on remote
- `--exclude-wpconfig` - Exclude wp-config.php from rsync (default: yes)
- `--no-exclude-wpconfig` - Include wp-config.php in sync
- `--disable-wp-debug` - Temporarily disable WP_DEBUG during push

### Examples

#### First Time Configuration
```bash
./wp-push-remote.sh --config
# Prompts for source/remote paths with smart defaults
# Saves to ~/.wp-push-remote.conf automatically
```

#### Run with Saved Configuration
```bash
./wp-push-remote.sh
# Uses saved settings - ready to go!
```

#### Install Plugins on Remote
```bash
./wp-push-remote.sh --install-plugins "woocommerce contact-form-7 wordpress-seo"
```

#### Files Only (No Database)
```bash
./wp-push-remote.sh --files-only
```

#### Unattended Mode with Exclusions
```bash
./wp-push-remote.sh -u -e "uploads cache .git"
```

#### Skip Search-Replace
```bash
./wp-push-remote.sh --no-search-replace
```

#### Delete SSH Key Pairs
```bash
./wp-push-remote.sh --del-ssh-key
# Deletes SSH key pairs for the configured remote user
# Shows details of deleted keys
# Reminds you to manually remove public key from remote server
```

#### Combined Options
```bash
./wp-push-remote.sh --install-plugins "akismet jetpack" -e "uploads cache"
```

## SSH Key Management

The script automatically generates SSH keys for secure authentication. After completing a push operation, you can delete these keys if desired.

### Deleting SSH Keys

To delete SSH key pairs:
```bash
./wp-push-remote.sh --del-ssh-key
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

When you run `./wp-push-remote.sh --config`, you'll be prompted for:
- **Source path prefix**: e.g., `/sites/example.com/`
- **Source webroot**: e.g., `files` or `public_html`
- **Remote IP/hostname**: e.g., `192.168.1.100` or `staging.example.com`
- **Remote user**: SSH username on remote server
- **Remote path prefix**: e.g., `/sites/staging.example.com/`
- **Remote webroot**: e.g., `files`

### Auto-Detection

The script automatically detects:
- **WordPress URLs**: Via `wp option get siteurl` on both sites
- **Table prefixes**: Via `wp db prefix` command (WP-CLI best practice)
- **File paths**: Derived from your configured paths

### Smart Defaults

- Path structure defaults to `/sites/{domain}/files` pattern
- Press Enter to accept defaults shown in [brackets]
- Previous values remembered for easy updates

### Manual Editing

Edit `~/.wp-push-remote.conf` if needed:
```bash
source_path_prefix="/sites/example.com/"
source_webroot="files"
remote_ip_address="192.168.1.100"
remote_user="production"
remote_path_prefix="/sites/staging.example.com/"
remote_webroot="files"
```

### Default Exclusions

These paths are excluded by default:
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
./wp-push-remote.sh --install-plugins "plugin-slug1 plugin-slug2 plugin-slug3"
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

1. Check that wp-cli.yml is configured correctly on the remote server
2. Verify database credentials in remote wp-config.php
3. Ensure sufficient disk space on remote server

### Rsync Errors

1. Verify source and remote paths are correct
2. Check SSH connectivity
3. Ensure sufficient permissions on both source and remote

## Security Considerations

- **wp-config.php**: Excluded by default to prevent overwriting remote configuration
- **SSH Keys**: Ed25519 keys (preferred) for better security on Ubuntu 24.04+
- **Database Cleanup**: Temporary SQL files cleaned up after import
- **Unattended Mode**: Use cautiously - skips confirmations
- **Systemd Logging**: All operations logged for audit trail
- **Table Prefix Sync**: Requires confirmation before resetting remote database

### Viewing Logs

```bash
# View all logs
journalctl -t wp-push-remote

# Follow in real-time
journalctl -t wp-push-remote -f

# Today's logs only
journalctl -t wp-push-remote --since today
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This script is provided as-is for use in WordPress deployments.

## Author

**gb@wpnet.nz**

## Version History

- **v2.0.4**: Current version
  - Configuration simplified: use `--config` instead of `--prompt-config`
  - No more database configuration prompts during setup
  - Auto-detection of URLs via WP-CLI
  - Table prefix detection using `wp db prefix` command (best practice)
  - Table prefix synchronization with confirmation
  - Enhanced `--install-plugins` to accept space-delimited plugin list
  - All database operations controlled via CLI flags
  - Improved search-replace with auto-detected values
  - Single cache flush after all operations
  - Better error handling and user feedback
  
- **v2.0.0**: Major update
  - Interactive configuration with prompts
  - Colorized output for better UX
  - Boolean flag syntax
  - Custom exclusion support
  - Ubuntu 24.04+ optimizations
  - Ed25519 SSH key support
  - Systemd journal logging
  - Enhanced validation
  - Automatic cleanup on interruption
  
- **v1.8.1**: Previous stable version

## Support

For issues, questions, or suggestions, please open an issue on GitHub.

## Notes

- This script is optimized for Ubuntu 24.04 LTS and higher
- It uses modern bash features (5.1+) and Ubuntu-specific tools
- SSH keys are generated using Ed25519 algorithm for better performance
- All operations are logged to systemd journal for audit purposes
- The script validates the environment before execution
