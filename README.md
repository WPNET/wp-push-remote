# WP Push Remote

A powerful bash script to push WordPress sites from a SOURCE server to a REMOTE server using WP-CLI and rsync. Optimized for Ubuntu 24.04 LTS and higher. Features include database migration with search-replace, file synchronization with exclusions, an interactive configuration mode, and systemd journal logging.

## Features

- 🚀 **Interactive Configuration Mode**: Prompt-based setup for all configuration variables
- 🎨 **Colorized Output**: Beautiful, user-friendly terminal interface
- 🔧 **Flexible Options**: Command-line arguments for all configuration flags
- 📁 **Custom Exclusions**: Add custom paths to exclude from rsync
- 🔄 **Database Migration**: Automatic database export, transfer, and import
- 🔍 **Search-Replace**: Built-in wp-cli search-replace for URLs and file paths
- 🔐 **Modern SSH Keys**: Ed25519 key generation for better security and performance
- ⚙️ **Multiple Modes**: Interactive, unattended, and files-only modes
- 📊 **Progress Reporting**: Detailed output with execution time tracking
- 📝 **Systemd Integration**: Automatic logging to systemd journal
- 🛡️ **Ubuntu Optimized**: Best practices for Ubuntu 24.04 LTS+

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

### Basic Usage

Run with interactive configuration prompts:
```bash
./wp-push-remote.sh --prompt-config
```

### Display Help

```bash
./wp-push-remote.sh --help
```

### Command-Line Options

#### General Options

- `-h, --help` - Show help message
- `-u, --unattended` - Run in unattended mode (no prompts, assumes YES for all confirmations)
- `-i, --interactive` - Run in interactive mode (default)
- `-p, --prompt-config` - Prompt for all configuration settings at startup

#### Exclusions

- `-e, --exclude PATH` - Add path to exclude list (can be used multiple times)
  ```bash
  ./wp-push-remote.sh -e "uploads" -e ".git" -e ".maintenance"
  ```

#### Option Flags

All option flags accept values `1` (YES) or `0` (NO):

- `--search-replace VALUE` - Run wp search-replace on database (default: 1)
- `--files-only VALUE` - Skip all database operations (default: 0)
- `--no-db-import VALUE` - Don't import database on remote (default: 0)
- `--install-plugins VALUE` - Install plugins on remote (default: 0)
- `--run-remote-commands VALUE` - Run custom commands on remote (default: 0)
- `--exclude-wpconfig VALUE` - Exclude wp-config.php from rsync (default: 1)
- `--disable-wp-debug VALUE` - Temporarily disable WP_DEBUG during push (default: 0)

### Examples

#### Example 1: Interactive Setup
```bash
./wp-push-remote.sh --prompt-config
```
This will prompt you for:
- Source server path and webroot
- Remote server IP, user, path, and webroot
- Database handling options (with search-replace, without, or files only)
- Search-replace URLs and paths (if needed)

#### Example 2: Unattended Mode with Custom Exclusions
```bash
./wp-push-remote.sh -u -e "uploads" -e ".maintenance"
```

#### Example 3: Files Only (No Database)
```bash
./wp-push-remote.sh --files-only 1
```

#### Example 4: Skip Search-Replace
```bash
./wp-push-remote.sh --search-replace 0
```

#### Example 5: Combined Options
```bash
./wp-push-remote.sh -p --disable-wp-debug 1 -e "node_modules"
```

## Configuration

### Default Configuration

The script includes default configuration values that can be edited directly in the script:

```bash
# SOURCE
source_path_prefix="/sites/mysite.co.nz/"
source_webroot="files"

# REMOTE
remote_ip_address=""
remote_user=""
remote_path_prefix="/sites/mysite2.co.nz/"
remote_webroot="files"

# WP-CLI search-replace
wp_search_replace_source_url='//'
wp_search_replace_remote_url='//'
wp_search_replace_source_path='/'
wp_search_replace_remote_path='/'
```

### Default Exclusions

By default, the following paths are excluded from rsync:
- `.wp-stats`
- `.maintenance`
- `wp-content/cache`
- `wp-content/uploads/wp-migrate-db`
- `/wp-content/updraft`
- `wp-content/uploads-old`
- `.user.ini`
- `wp-config.php` (if `exclude_wpconfig=1`)

Add custom exclusions using the `-e` flag or by editing the `excludes` array in the script.

## Database Handling Options

When using `--prompt-config`, you'll be asked how to handle the database:

1. **Copy database and perform search-replace**: Copies the database and performs URL and path rewrites (recommended for staging/development environments)

2. **Copy database without modifications**: Copies the database as-is without any search-replace operations

3. **Files only**: Skips all database operations and only syncs files

## SSH Key Management

The script automatically manages SSH keys for connecting to the remote server:

1. Checks for existing SSH key: `~/.ssh/id_rsa_remote_${remote_user}`
2. Prompts to generate a new key if not found (in interactive mode)
3. Tests the connection to the remote server
4. Optionally removes the key pair after the push is complete

## Workflow

1. **Configuration**: Set up source and remote details (via prompts or command-line args)
2. **SSH Setup**: Generate or use existing SSH key for remote access
3. **Connection Test**: Verify SSH connection to remote server
4. **Database Export**: Export source database (unless files-only mode)
5. **File Sync**: Rsync files to remote with exclusions
6. **Database Import**: Import database on remote (if applicable)
7. **Search-Replace**: Perform URL and path rewrites (if enabled)
8. **Custom Commands**: Run any custom commands (if enabled)
9. **Plugin Installation**: Install plugins (if enabled)
10. **Cleanup**: Remove temporary files and optionally SSH keys

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

- **wp-config.php**: By default, excluded from rsync to prevent overwriting remote configuration
- **SSH Keys**: Ed25519 keys generated by default for better security and performance on Ubuntu 24.04+
- **Database Backups**: Automatically cleaned up after successful import
- **Unattended Mode**: Use with caution in production environments
- **Systemd Logging**: All operations logged to systemd journal for audit trail

### Viewing Logs

```bash
# View wp-push-remote logs
journalctl -t wp-push-remote

# Follow logs in real-time
journalctl -t wp-push-remote -f

# View logs from today
journalctl -t wp-push-remote --since today
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This script is provided as-is for use in WordPress deployments.

## Author

**gb@wpnet.nz**

## Version History

- **v2.0.0**: Major update with:
  - Interactive configuration with prompts for all settings
  - Colorized output for better UX
  - Comprehensive argument parsing for all options
  - Custom exclusion support via -e/--exclude flag
  - Help system with -h/--help
  - Ubuntu 24.04+ optimizations
  - Ed25519 SSH key support (preferred over RSA)
  - Systemd journal logging integration
  - Enhanced validation and error handling
  - Automatic cleanup on interruption
  - Better cross-command compatibility
- **v1.8.1**: Previous stable version

## Support

For issues, questions, or suggestions, please open an issue on GitHub.

## Notes

- This script is optimized for Ubuntu 24.04 LTS and higher
- It uses modern bash features (5.1+) and Ubuntu-specific tools
- SSH keys are generated using Ed25519 algorithm for better performance
- All operations are logged to systemd journal for audit purposes
- The script validates the environment before execution
