#!/bin/bash

# Check if the input file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <user_list_file>"
    exit 1
fi

user_list_file="$1"

# Log and password file paths
log_file="/var/log/user_management.log"
password_file="/var/secure/user_passwords.txt"

# Create the necessary directories and set permissions
mkdir -p /var/log
mkdir -p /var/secure
touch "$log_file"
touch "$password_file"
chmod 600 "$password_file"

# Function to log actions
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

# Read the user list file
while IFS=';' read -r username groups; do
    # Remove whitespace
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    # Ensure all specified groups exist
    for group in $(echo "$groups" | tr ',' ' '); do
        if ! getent group "$group" >/dev/null; then
            groupadd "$group"
            if [ $? -eq 0 ]; then
                log_action "Created group $group"
            else
                log_action "Failed to create group $group"
                continue
            fi
        else
            log_action "Group $group already exists"
        fi
    done

    # Create the personal group
    if ! getent group "$username" >/dev/null; then
        groupadd "$username"
        if [ $? -eq 0 ]; then
            log_action "Created group $username"
        else
            log_action "Failed to create group $username"
            continue
        fi
    else
        log_action "Group $username already exists"
    fi

    # Create the user with the personal group
    if ! id -u "$username" >/dev/null 2>&1; then
        useradd -m -g "$username" -s /bin/bash "$username"
        if [ $? -eq 0 ]; then
            log_action "Created user $username with personal group $username"

            # Set the user's additional groups
            if [ -n "$groups" ]; then
                usermod -aG "$groups" "$username"
                if [ $? -eq 0 ]; then
                    log_action "Added user $username to groups $groups"
                else
                    log_action "Failed to add user $username to groups $groups"
                fi
            fi

            # Generate a random password
            password=$(openssl rand -base64 12)
            echo "$username:$password" | chpasswd
            if [ $? -eq 0 ]; then
                log_action "Set password for user $username"
            else
                log_action "Failed to set password for user $username"
            fi

            # Save the password securely
            echo "$username,$password" >> "$password_file"
        else
            log_action "Failed to create user $username"
        fi
    else
        log_action "User $username already exists"
    fi

    # Set home directory permissions
    chmod 700 "/home/$username"
    chown "$username:$username" "/home/$username"
    log_action "Set permissions for /home/$username"
done < "$user_list_file"

log_action "Script execution completed."
