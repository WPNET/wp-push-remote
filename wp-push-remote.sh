#!/bin/bash

script_version="2.0.0"
# Author:       gb@wpnet.nz
# Description:  Push a site from SOURCE server to REMOTE. Run this script from the SOURCE server.
# Requirements: WP-CLI installed on source and remote
#               wp-cli.yml to be configured in the source and remote site owner's home directory, with the correct path to the WP installation

####################################################################################
# COLOR DEFINITIONS FOR BETTER UX
####################################################################################

# Check if terminal supports colors
if [[ -t 1 ]]; then
    # Colors
    COLOR_RESET='\033[0m'
    COLOR_RED='\033[0;31m'
    COLOR_GREEN='\033[0;32m'
    COLOR_YELLOW='\033[0;33m'
    COLOR_BLUE='\033[0;34m'
    COLOR_MAGENTA='\033[0;35m'
    COLOR_CYAN='\033[0;36m'
    COLOR_WHITE='\033[1;37m'
    # Bold colors
    COLOR_BOLD_GREEN='\033[1;32m'
    COLOR_BOLD_YELLOW='\033[1;33m'
    COLOR_BOLD_BLUE='\033[1;34m'
    COLOR_BOLD_CYAN='\033[1;36m'
else
    # No colors
    COLOR_RESET=''
    COLOR_RED=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_BLUE=''
    COLOR_MAGENTA=''
    COLOR_CYAN=''
    COLOR_WHITE=''
    COLOR_BOLD_GREEN=''
    COLOR_BOLD_YELLOW=''
    COLOR_BOLD_BLUE=''
    COLOR_BOLD_CYAN=''
fi

####################################################################################
# HELPER FUNCTIONS
####################################################################################

# Print functions
print_header() {
    echo -e "\n${COLOR_BOLD_CYAN}==== $1 ====${COLOR_RESET}"
}

print_info() {
    echo -e "${COLOR_CYAN}[INFO]${COLOR_RESET} $1"
}

print_success() {
    echo -e "${COLOR_BOLD_GREEN}[SUCCESS]${COLOR_RESET} $1"
}

print_warning() {
    echo -e "${COLOR_BOLD_YELLOW}[WARNING]${COLOR_RESET} $1"
}

print_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1"
}

print_step() {
    echo -e "\n${COLOR_BOLD_BLUE}++++ $1${COLOR_RESET}"
}

# Help function
show_help() {
    cat << EOF
${COLOR_BOLD_CYAN}WP Push Remote v${script_version}${COLOR_RESET}
${COLOR_WHITE}Push a WordPress site from SOURCE server to REMOTE using WP-CLI and rsync${COLOR_RESET}

${COLOR_BOLD_GREEN}USAGE:${COLOR_RESET}
    $0 [OPTIONS]

${COLOR_BOLD_GREEN}OPTIONS:${COLOR_RESET}
    ${COLOR_YELLOW}-h, --help${COLOR_RESET}              Show this help message
    ${COLOR_YELLOW}-u, --unattended${COLOR_RESET}       Run in unattended mode (no prompts)
    ${COLOR_YELLOW}-i, --interactive${COLOR_RESET}      Run in interactive mode (default)
    ${COLOR_YELLOW}-p, --prompt-config${COLOR_RESET}    Prompt for all configuration settings
    
    ${COLOR_YELLOW}-e, --exclude PATH${COLOR_RESET}     Add path to exclude list (can be used multiple times)
                                Example: -e "uploads" -e ".git"
    
    ${COLOR_BOLD_CYAN}Option Flags (1=YES, 0=NO):${COLOR_RESET}
    ${COLOR_YELLOW}--search-replace VALUE${COLOR_RESET}     Run wp search-replace (default: 1)
    ${COLOR_YELLOW}--files-only VALUE${COLOR_RESET}         Skip database operations (default: 0)
    ${COLOR_YELLOW}--no-db-import VALUE${COLOR_RESET}       Don't import database on remote (default: 0)
    ${COLOR_YELLOW}--install-plugins VALUE${COLOR_RESET}    Install plugins on remote (default: 0)
    ${COLOR_YELLOW}--run-remote-commands VALUE${COLOR_RESET} Run custom commands on remote (default: 0)
    ${COLOR_YELLOW}--exclude-wpconfig VALUE${COLOR_RESET}   Exclude wp-config.php (default: 1)
    ${COLOR_YELLOW}--disable-wp-debug VALUE${COLOR_RESET}   Disable WP_DEBUG temporarily (default: 0)

${COLOR_BOLD_GREEN}EXAMPLES:${COLOR_RESET}
    # Run with interactive prompts for configuration
    $0 --prompt-config
    
    # Run in unattended mode with custom exclusions
    $0 -u -e "uploads" -e ".maintenance"
    
    # Files only, no database operations
    $0 --files-only 1
    
    # Skip search-replace operation
    $0 --search-replace 0

${COLOR_BOLD_GREEN}REQUIREMENTS:${COLOR_RESET}
    - WP-CLI installed on both source and remote servers
    - wp-cli.yml configured in home directory with correct WP installation path
    - SSH access to remote server

${COLOR_BOLD_GREEN}CONFIGURATION:${COLOR_RESET}
    Edit the script to set default values for:
    - SOURCE: source_path_prefix, source_webroot
    - REMOTE: remote_ip_address, remote_user, remote_path_prefix, remote_webroot
    - WP-CLI search-replace URLs and paths
    
    Or use --prompt-config to set these interactively at runtime.

EOF
    exit 0
}

####################################################################################
# DEFAULT CONFIGURATION - Can be overridden via --prompt-config option
####################################################################################

# SOURCE
source_path_prefix="/sites/mysite.co.nz/" # use trailing slash
source_webroot="files" # no preceding or trailing slash

# REMOTE
remote_ip_address=""
remote_user=""
remote_path_prefix="/sites/mysite2.co.nz/" # use trailing slash
remote_webroot="files" # no preceding or trailing slash
plugins_to_install="" # space separated list of plugins to install on remote

# WP-CLI search-replace
# rewrites for URLs
wp_search_replace_source_url='//'
wp_search_replace_remote_url='//'
# rewrites for file paths
wp_search_replace_source_path='/'
wp_search_replace_remote_path='/'

# Options flags (1 = YES, 0 = NO)
do_search_replace=1    # run 'wp search-replace' on remote, once for URLs and once for file paths
files_only=0           # don't do a database dump & import
no_db_import=0         # don't run db import on remote
install_plugins=0      # install plugins on remote
run_remote_commands=0  # Run custom commands on remote (see below)
exclude_wpconfig=1     # exclude the wp-config.php file from the rsync to remote, you probably don't want to change this
unattended_mode=0      # flag for unattended mode
disable_wp_debug=0     # disable WP_DEBUG on remote for the duration of the push, then revert it back to the original state
prompt_config=0        # flag to prompt for configuration

# Excludes for rsync to remote (edit as required)
excludes=(.wp-stats .maintenance wp-content/cache wp-content/uploads/wp-migrate-db /wp-content/updraft wp-content/uploads-old .user.ini)
# Or just add to the array like this:
# excludes+=(.user.ini)

####################################################################################
# NO MORE EDITING BELOW THIS LINE!
####################################################################################

# Function to handle user prompts
function user_prompt() {
    if [[ $unattended_mode -eq 0 ]]; then
        while true; do
            read -p "$(echo -e "\\n${COLOR_YELLOW}CONFIRM:${COLOR_RESET} ${1} ${COLOR_GREEN}Are you sure? [Yes/no]${COLOR_RESET} ") " user_input
            case $user_input in
                [Yy]* ) return 0;;
                "" ) return 0;;
                [Nn]* ) return 1;;
                * ) echo -e "${COLOR_YELLOW}Please respond yes [Y/y/{enter}] or no [n].${COLOR_RESET}";;
            esac
        done
    else
        print_info "CONFIRM: ${1} - Assuming YES in unattended mode."
        return 0
    fi
}

# Function to prompt for configuration
function prompt_for_config() {
    print_header "CONFIGURATION SETUP"
    
    print_info "Let's configure the SOURCE and REMOTE settings."
    echo ""
    
    # SOURCE configuration
    print_step "SOURCE Configuration"
    read -p "$(echo -e "${COLOR_CYAN}Source path prefix${COLOR_RESET} (e.g., /sites/mysite.co.nz/): ")" input_source_path_prefix
    if [[ -n "$input_source_path_prefix" ]]; then
        source_path_prefix="$input_source_path_prefix"
    fi
    
    read -p "$(echo -e "${COLOR_CYAN}Source webroot${COLOR_RESET} (e.g., files or public_html): ")" input_source_webroot
    if [[ -n "$input_source_webroot" ]]; then
        source_webroot="$input_source_webroot"
    fi
    
    # REMOTE configuration
    print_step "REMOTE Configuration"
    read -p "$(echo -e "${COLOR_CYAN}Remote IP address or hostname${COLOR_RESET}: ")" input_remote_ip
    if [[ -n "$input_remote_ip" ]]; then
        remote_ip_address="$input_remote_ip"
    fi
    
    read -p "$(echo -e "${COLOR_CYAN}Remote SSH user${COLOR_RESET}: ")" input_remote_user
    if [[ -n "$input_remote_user" ]]; then
        remote_user="$input_remote_user"
    fi
    
    read -p "$(echo -e "${COLOR_CYAN}Remote path prefix${COLOR_RESET} (e.g., /sites/mysite2.co.nz/): ")" input_remote_path_prefix
    if [[ -n "$input_remote_path_prefix" ]]; then
        remote_path_prefix="$input_remote_path_prefix"
    fi
    
    read -p "$(echo -e "${COLOR_CYAN}Remote webroot${COLOR_RESET} (e.g., files or public_html): ")" input_remote_webroot
    if [[ -n "$input_remote_webroot" ]]; then
        remote_webroot="$input_remote_webroot"
    fi
    
    # Database operations
    print_step "Database Configuration"
    while true; do
        echo -e "\n${COLOR_CYAN}How should the database be handled?${COLOR_RESET}"
        echo "  1) Copy database and perform search-replace (URL and path rewrites)"
        echo "  2) Copy database without modifications (no search-replace)"
        echo "  3) Files only (skip database operations entirely)"
        read -p "$(echo -e "${COLOR_GREEN}Select option [1-3]:${COLOR_RESET} ")" db_option
        
        case $db_option in
            1)
                do_search_replace=1
                files_only=0
                no_db_import=0
                print_success "Database will be copied with search-replace"
                
                # Get search-replace values
                echo -e "\n${COLOR_CYAN}Search-Replace Configuration:${COLOR_RESET}"
                read -p "$(echo -e "${COLOR_CYAN}Source URL${COLOR_RESET} (e.g., //example.com): ")" input_source_url
                if [[ -n "$input_source_url" ]]; then
                    wp_search_replace_source_url="$input_source_url"
                fi
                
                read -p "$(echo -e "${COLOR_CYAN}Remote URL${COLOR_RESET} (e.g., //staging.example.com): ")" input_remote_url
                if [[ -n "$input_remote_url" ]]; then
                    wp_search_replace_remote_url="$input_remote_url"
                fi
                
                read -p "$(echo -e "${COLOR_CYAN}Source file path${COLOR_RESET} (e.g., /var/www/site): ")" input_source_path
                if [[ -n "$input_source_path" ]]; then
                    wp_search_replace_source_path="$input_source_path"
                fi
                
                read -p "$(echo -e "${COLOR_CYAN}Remote file path${COLOR_RESET} (e.g., /var/www/staging): ")" input_remote_path
                if [[ -n "$input_remote_path" ]]; then
                    wp_search_replace_remote_path="$input_remote_path"
                fi
                break
                ;;
            2)
                do_search_replace=0
                files_only=0
                no_db_import=0
                print_success "Database will be copied without modifications"
                break
                ;;
            3)
                files_only=1
                do_search_replace=0
                no_db_import=1
                print_success "Only files will be copied (database skipped)"
                break
                ;;
            *)
                print_warning "Invalid option. Please select 1, 2, or 3."
                ;;
        esac
    done
}

####################################################################################
# Process command line arguments
####################################################################################

# Parse long options
TEMP=$(getopt -o h,u,i,p,e: --long help,unattended,interactive,prompt-config,exclude:,search-replace:,files-only:,no-db-import:,install-plugins:,run-remote-commands:,exclude-wpconfig:,disable-wp-debug: -n "$0" -- "$@" 2>/dev/null)

# Check for getopt errors
if [[ $? -ne 0 ]]; then
    # Fallback to basic getopts if getopt is not available or fails
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                ;;
            -u|--unattended)
                unattended_mode=1
                shift
                ;;
            -i|--interactive)
                unattended_mode=0
                shift
                ;;
            -p|--prompt-config)
                prompt_config=1
                shift
                ;;
            -e|--exclude)
                excludes+=("$2")
                shift 2
                ;;
            --search-replace)
                do_search_replace="$2"
                shift 2
                ;;
            --files-only)
                files_only="$2"
                shift 2
                ;;
            --no-db-import)
                no_db_import="$2"
                shift 2
                ;;
            --install-plugins)
                install_plugins="$2"
                shift 2
                ;;
            --run-remote-commands)
                run_remote_commands="$2"
                shift 2
                ;;
            --exclude-wpconfig)
                exclude_wpconfig="$2"
                shift 2
                ;;
            --disable-wp-debug)
                disable_wp_debug="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
else
    eval set -- "$TEMP"

    while true; do
        case "$1" in
            -h|--help)
                show_help
                ;;
            -u|--unattended)
                unattended_mode=1
                shift
                ;;
            -i|--interactive)
                unattended_mode=0
                shift
                ;;
            -p|--prompt-config)
                prompt_config=1
                shift
                ;;
            -e|--exclude)
                excludes+=("$2")
                shift 2
                ;;
            --search-replace)
                do_search_replace="$2"
                shift 2
                ;;
            --files-only)
                files_only="$2"
                shift 2
                ;;
            --no-db-import)
                no_db_import="$2"
                shift 2
                ;;
            --install-plugins)
                install_plugins="$2"
                shift 2
                ;;
            --run-remote-commands)
                run_remote_commands="$2"
                shift 2
                ;;
            --exclude-wpconfig)
                exclude_wpconfig="$2"
                shift 2
                ;;
            --disable-wp-debug)
                disable_wp_debug="$2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
fi

####################################################################################
# Set up
####################################################################################

# Clear the screen
clear

# Show banner
print_header "WP Push Remote v${script_version}"

# Prompt for configuration if requested
if [[ $prompt_config -eq 1 ]]; then
    prompt_for_config
fi

# Set up random rnd_str for database backup filename
rnd_str=$(echo $RANDOM | md5sum | head -c 12; echo;)
rnd_str_key="38fh"

# Set paths / prefixes
db_export_prefix="wp_db_export_"
source_path="${source_path_prefix}${source_webroot}"
remote_path="${remote_path_prefix}${remote_webroot}"
source_db_name="${db_export_prefix}${rnd_str}${rnd_str_key}.sql"
current_user=$(whoami)

if (( exclude_wpconfig == 1 )); then
    excludes+=(wp-config.php)
fi

print_step "START WP PUSH site FROM $(hostname -I)TO ${remote_ip_address}"
print_info "Script: 'wp-push-remote.sh' v${script_version}"
print_info "Source URL: $( wp option get siteurl 2>/dev/null || echo 'Unable to detect' )"
echo -e "${COLOR_CYAN}Source:${COLOR_RESET} ${current_user}@${source_path}"
echo -e "${COLOR_CYAN}Remote:${COLOR_RESET} ${remote_user}@${remote_ip_address}:${remote_path}"
echo -e "${COLOR_CYAN}Excludes:${COLOR_RESET} ${excludes[*]}"

# Display option flags
print_info "Configuration Flags:"
echo -e "  ${COLOR_CYAN}do_search_replace:${COLOR_RESET} ${do_search_replace}"
echo -e "  ${COLOR_CYAN}files_only:${COLOR_RESET} ${files_only}"
echo -e "  ${COLOR_CYAN}no_db_import:${COLOR_RESET} ${no_db_import}"
echo -e "  ${COLOR_CYAN}install_plugins:${COLOR_RESET} ${install_plugins}"
echo -e "  ${COLOR_CYAN}exclude_wpconfig:${COLOR_RESET} ${exclude_wpconfig}"
echo -e "  ${COLOR_CYAN}disable_wp_debug:${COLOR_RESET} ${disable_wp_debug}"

if [[ ! -f ~/.ssh/id_rsa_remote_${remote_user} ]]; then
    if [[ $unattended_mode -eq 0 ]]; then
        if ( user_prompt "No SSH key found - OK to generate one now?" ); then
            # Gen SSH key
            ssh-keygen -t rsa -b 4096 -C "${current_user}@$(hostname -I) - Added by wp-push-remote.sh" -f ~/.ssh/id_rsa_remote_${remote_user}
            print_success "SSH key generated: ~/.ssh/id_rsa_remote_${remote_user}"
            echo -e "\n${COLOR_BOLD_YELLOW}Public key:${COLOR_RESET}\n"
            cat ~/.ssh/id_rsa_remote_${remote_user}.pub
            echo -e "\n\n${COLOR_BOLD_YELLOW}IMPORTANT:${COLOR_RESET} Add this key to the REMOTE server's authorized_keys file for user '${remote_user}'"
        else
            print_error "ABORTED!"
            exit 1
        fi
    else
        print_warning "No SSH key found - Skipping key generation in unattended mode."
    fi
fi

if [[ $unattended_mode -eq 0 ]]; then
    if ( user_prompt "Test the connection to the remote server?" ); then
        print_step "Testing the connection: ssh ${remote_user}@${remote_ip_address}"
        print_info "If you get a password prompt, then the key is not set up correctly."
        sleep 1
        ssh -q -t -i ~/.ssh/id_rsa_remote_${remote_user} ${remote_user}@${remote_ip_address} << EOF
shopt -s dotglob
echo -e "\n${COLOR_BOLD_GREEN}SUCCESS! Connected to REMOTE: \$(whoami)@\$(hostname) (\$(hostname -I))${COLOR_RESET}"
echo -e "Returning to the local server ..."
sleep 1
EOF
    else
        print_warning "Connection NOT tested!"
    fi
else
    print_info "Skipping connection test in unattended mode."
fi

if ( ! user_prompt "Proceed with the site PUSH?"); then
    print_error "ABORTED!"
    exit 1
fi

####################################################################################
# Run PUSH
####################################################################################

print_header "STARTING PUSH OPERATION"

# Record start time
start_time=$(date +%s)

if (( files_only == 0 ))
then
    # Dump database
    print_step "EXPORTING database ..."
    wp db export ${source_path}/${source_db_name}
fi

# Push files to remote
print_step "RSYNC-ing files to REMOTE ..."

# run rsync with exclusions
rsync -e "ssh -i ~/.ssh/id_rsa_remote_${remote_user}" -azhP --delete $(printf -- "--exclude=%q " "${excludes[@]}") ${source_path}/ ${remote_user}@${remote_ip_address}:${remote_path}

# Connect to remote and run local commands
print_step "EXECUTING post-deployment commands on REMOTE (${remote_ip_address})..."
ssh -i ~/.ssh/id_rsa_remote_${remote_user} ${remote_user}@${remote_ip_address} << EOF
shopt -s dotglob
echo -e "\n${COLOR_CYAN}Connected to REMOTE: \$(whoami)@\$(hostname) (\$(hostname -I))${COLOR_RESET}"

if (( ${disable_wp_debug} == 1 )); then
echo -e "\n${COLOR_BLUE}Creating backup of wp-config.php ...${COLOR_RESET}"
cp -v ${remote_path}/wp-config.php ${remote_path}/wp-config.php.bak
# Disable WP_DEBUG to reduce output noise to the terminal
echo -e "${COLOR_BLUE}Disabling WP_DEBUG in wp-config.php ...${COLOR_RESET}"
sed -i "s/define(\s*'WP_DEBUG'.*/define('WP_DEBUG', false);/g" ${remote_path}/wp-config.php
fi

if (( ${files_only} == 0 && ${no_db_import} == 0 )); then
echo -e "${COLOR_BLUE}IMPORTING database ...${COLOR_RESET}"
wp db import ${remote_path}/${source_db_name}
echo -e "${COLOR_BLUE}FLUSHING WP cache ...${COLOR_RESET}"
wp cache flush --hard
echo -e "\n${COLOR_BLUE}DELETING imported database source file ...${COLOR_RESET}"
rm -v ${remote_path}/${source_db_name}
fi

if (( ${do_search_replace} == 1 && ${files_only} == 0 && ${no_db_import} == 0 )); then
if [[ ${wp_search_replace_source_url} != '//' && ${wp_search_replace_remote_url} != '//' ]]; then
echo -e "\n${COLOR_BLUE}EXECUTING 'wp search-replace' for URLs ...${COLOR_RESET}"
wp search-replace --precise ${wp_search_replace_source_url} ${wp_search_replace_remote_url} --report-changed-only --format=table
fi
if [[ ${wp_search_replace_source_path} != '/' && ${wp_search_replace_remote_path} != '/' ]]; then
echo -e "\n${COLOR_BLUE}EXECUTING 'wp search-replace' for file PATHs ...${COLOR_RESET}"
wp search-replace --precise ${wp_search_replace_source_path} ${wp_search_replace_remote_path} --report-changed-only --format=table
fi
echo -e "${COLOR_BLUE}FLUSHING WP cache ...${COLOR_RESET}"
wp cache flush --hard
fi

if (( ${run_remote_commands} == 1 )); then
echo -e "\n${COLOR_BLUE}EXECUTING custom commands on remote ...${COLOR_RESET}"
# Use for running custom commands on the remote, after DB import and search-replace, for example:
# this runs a url_replace with Elementor
#echo -e "\n${COLOR_BLUE}Running Elementor replace_urls on remote server ...${COLOR_RESET}"
#wp elementor replace_urls https:${wp_search_replace_source_url} https:${wp_search_replace_remote_url}
fi

if (( ${install_plugins} == 1 )) && [[ "${plugins_to_install}" != "" ]]; then
echo -e "\n${COLOR_BLUE}INSTALLING plugins on remote ...${COLOR_RESET}"
wp plugin install ${plugins_to_install}
wp cache flush
fi

if (( ${disable_wp_debug} == 1 )); then
# Revert wp-config
echo -e "\n${COLOR_BLUE}Restoring wp-config.php from backup ...${COLOR_RESET}"
mv -v ${remote_path}/wp-config.php.bak ${remote_path}/wp-config.php
fi
EOF

if (( files_only == 0 )); then
    print_step "DELETING database backup from source server ..."
    rm -v ${source_path}/${db_export_prefix}*${rnd_str_key}.sql # tidy up DB dumps
fi

# Calculate execution time
end_time=$(date +%s)
execution_time=$((end_time - start_time))
minutes=$((execution_time / 60))
seconds=$((execution_time % 60))
print_success "Total execution time: ${minutes}:$(printf %02d ${seconds})"

if ( ! user_prompt "Keep the SSH key pair on the local server?" ); then
    # Remove SSH key pair
    print_step "REMOVING SSH key pair ..."
    rm -fv ~/.ssh/id_rsa_remote_${remote_user} ~/.ssh/id_rsa_remote_${remote_user}.pub
    print_warning "The private + public keys have been removed from the local server."
    print_warning "The public key must be MANUALLY removed from the REMOTE server's authorized_keys file for user '${remote_user}'"
fi

print_success "COMPLETED!"
echo -e "\n${COLOR_BOLD_GREEN}========================================${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}    Push operation completed!${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}========================================${COLOR_RESET}\n"
exit
