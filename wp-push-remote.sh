#!/bin/bash

script_version="1.8.1"
# Author:       gb@wpnet.nz
# Description:  Push a site from SOURCE server to REMOTE. Run this script from the SOURCE server.
# Requirements: WP-CLI installed on source and remote
#               wp-cli.yml to be configured in the source and remote site owner's home directory, with the correct path to the WP installation

####################################################################################
# EDIT FOLLOWING LINES ONLY!
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
exclude_wpconfig=1     # exclude the wp-config.php file from the rsnc to remote, you probably don't want to change this
unattended_mode=0      # flag for unattended mode
disable_wp_debug=0     # disable WP_DEBUG on remote for the duration of the push, then revert it back to the original state

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
            read -p "$(echo -e "\\nCONFIRM: ${1} Are you sure? [Yes/no]") " user_input
            case $user_input in
                [Yy]* ) break;;
                "" ) break;;
                [Nn]* ) return 1;;
                * ) echo "Please respond yes [Y/y/{enter}] or no [n].";;
            esac
        done
        return 0
    else
        echo -e "\nCONFIRM: ${1} - Assuming YES in unattended mode."
        return 0
    fi
}

####################################################################################
# Process command line arguments
####################################################################################

while getopts "ui" opt; do
  case $opt in
    u) 
      unattended_mode=1 # unattended mode
      ;;
    i) 
      unattended_mode=0 # interactive mode
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

####################################################################################
# Set up
####################################################################################

# Clear the screen
clear

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

echo -e "\n++++ START WP PUSH site FROM $(hostname -I)TO ${remote_ip_address}"
echo "Script: 'wp-cli-push-site.sh' v${script_version}"
echo "Source URL: $( wp option get siteurl )"
echo "Source: ${current_user}@${source_path}"
echo "Remote: ${remote_user}@${remote_ip_address}:${remote_path}"
echo "Excludes:" "${excludes[@]}"

if [[ ! -f ~/.ssh/id_rsa_remote_${remote_user} ]]; then
    if [[ $unattended_mode -eq 0 ]]; then
        if ( user_prompt "No SSH key found - OK to generate one now?" ); then
            # Gen SSH key
            ssh-keygen -t rsa -b 4096 -C "${current_user}@$(hostname -I) - Added by wp-cli-push-site.sh" -f ~/.ssh/id_rsa_remote_${remote_user}
            echo -e "\n++++ SSH key generated: ~/.ssh/id_rsa_remote_${remote_user}"
            echo -e "++++ Public key:\n"
            cat ~/.ssh/id_rsa_remote_${remote_user}.pub
            echo -e "\n\n++++ Add this key to the REMOTE server's authorized_keys file for user '${remote_user}'"
        else
            echo "++++ ABORTED!"
            exit 1
        fi
    else
        echo -e "\n++++ No SSH key found - Skipping key generation in unattended mode."
    fi
fi

if [[ $unattended_mode -eq 0 ]]; then
    if ( user_prompt "Test the connection to the remote server?" ); then
        echo -e "++++ Testing the connection: ssh ${remote_user}@${remote_ip_address}"
        echo -e "++++ If you get a password prompt, then the key is not set up correctly."
        sleep 1
        ssh -q -t -i ~/.ssh/id_rsa_remote_${remote_user} ${remote_user}@${remote_ip_address} << EOF
shopt -s dotglob
echo -e "\n++++ SUCCESS! Connected to REMOTE: \$(whoami)@\$(hostname) (\$(hostname -I))"
echo -e "Returning to the local server ..."
sleep 1
EOF
    else
        echo "++++ Connection NOT tested!"
    fi
else
    echo -e "\n++++ Skipping connection test in unattended mode."
fi

if ( ! user_prompt "Proceed with the site PUSH?"); then
    echo "++++ ABORTED!"
    exit 1
fi

####################################################################################
# Run PUSH
####################################################################################

# Record start time
start_time=$(date +%s)

if (( files_only == 0 ))
then
    # Dump database
    echo -e "\n++++ EXPORTING database ..."
    wp db export ${source_path}/${source_db_name}
fi

# Push files to remote
echo -e "\n++++ RSYNC-ing files to REMOTE ..."

# run rsync with exclusions
rsync -e "ssh -i ~/.ssh/id_rsa_remote_${remote_user}" -azhP --delete $(printf -- "--exclude=%q " "${excludes[@]}") ${source_path}/ ${remote_user}@${remote_ip_address}:${remote_path}

# Connect to remote and run local commands
echo -e "\n++++ EXECUTING post-deployment commands on REMOTE (${remote_ip_address})..."
ssh -i ~/.ssh/id_rsa_remote_${remote_user} ${remote_user}@${remote_ip_address} << EOF
shopt -s dotglob
echo -e "\n++++ Connected to REMOTE: \$(whoami)@\$(hostname) (\$(hostname -I))"

if (( ${disable_wp_debug} == 1 )); then
echo -e "\n++++ Creating backup of wp-config.php ..."
cp -v ${remote_path}/wp-config.php ${remote_path}/wp-config.php.bak
# Disable WP_DEBUG to reduce output noise to the terminal
echo -e "\n++++ Disabling WP_DEBUG in wp-config.php ..."
sed -i "s/define(\s*'WP_DEBUG'.*/define('WP_DEBUG', false);/g" ${remote_path}/wp-config.php
fi

if (( ${files_only} == 0 && ${no_db_import} == 0 )); then
echo "++++ IMPORTING database ..."
wp db import ${remote_path}/${source_db_name}
echo "++++ FLUSHING WP cache ..."
wp cache flush --hard
echo -e "\n++++ DELETING imported database source file ..."
rm -v ${remote_path}/${source_db_name}
fi

if (( ${do_search_replace} == 1 && ${files_only} == 0 && ${no_db_import} == 0 )); then
if [[ ${wp_search_replace_source_url} != '//' && ${wp_search_replace_remote_url} != '//' ]]; then
echo -e "\n++++ EXECUTING 'wp search-replace' for URLs ..."
wp search-replace --precise ${wp_search_replace_source_url} ${wp_search_replace_remote_url} --report-changed-only --format=table
fi
if [[ ${wp_search_replace_source_path} != '/' && ${wp_search_replace_remote_path} != '/' ]]; then
echo -e "\n++++ EXECUTING 'wp search-replace' for file PATHs ..."
wp search-replace --precise ${wp_search_replace_source_path} ${wp_search_replace_remote_path} --report-changed-only --format=table
fi
echo "++++ FLUSHING WP cache ..."
wp cache flush --hard
fi

if (( ${run_remote_commands} == 1 )); then
echo -e "\n++++ EXECUTING custom commands on remote ..."
# Use for running custom commands on the remote, after DB import and search-replace, for example:
# this runs a url_replace with Elementor
#echo -e "\n++++ Running Elementor replace_urls on remote server ..."
#wp elementor replace_urls https:${wp_search_replace_source_url} https:${wp_search_replace_remote_url}
fi

if (( ${install_plugins} == 1 )) && [[ "$plugins_to_install" != "" ]]; then
echo -e "\n++++ INSTALLING plugins on remote ..."
wp plugin install ${plugins_to_install}
wp cache flush
fi

if (( ${disable_wp_debug} == 1 )); then
# Revert wp-config
echo -e "\n++++ Restoring wp-config.php from backup ..."
mv -v ${remote_path}/wp-config.php.bak ${remote_path}/wp-config.php
fi
EOF

if (( files_only == 0 )); then
    echo -e "\n++++ DELETING database backup from source server ..."
    rm -v ${source_path}/${db_export_prefix}*${rnd_str_key}.sql # tidy up DB dumps
fi

# Calculate execution time
end_time=$(date +%s)
execution_time=$((end_time - start_time))
minutes=$((execution_time / 60))
seconds=$((execution_time % 60))
echo -e "\n++++ Total execution time: ${minutes}:$(printf %02d ${seconds})"

if ( ! user_prompt "Keep the SSH key pair on the local server?" ); then
    # Remove SSH key pair
    echo -e "\n++++ REMOVING SSH key pair ..."
    rm -fv ~/.ssh/id_rsa_remote_${remote_user} ~/.ssh/id_rsa_remote_${remote_user}.pub
    echo -e "++++ The private + public keys have been removed from the local server."
    echo -e "++++ The public key must be MANUALLY removed from the REMOTE server's authorized_keys file for user '${remote_user}'"
fi

echo -e "\n++++ COMPLETED!"
exit
