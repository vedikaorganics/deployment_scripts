#!/bin/bash

# Function to execute command and log output
execute_command() {
    echo "Executing: $1"
    if ! eval "$1"; then
        echo "Error: Command failed: $1"
        exit 1
    else
        echo "Success: Command executed successfully: $1"
    fi
}

# Change directory into nodeserver
cd nodeserver || exit 1

# Clone nodeserver
execute_command "git pull --rebase"

# Change directory into deploy_scripts
cd .. || exit 1

# Build nodeserver image
execute_command "docker build -t vedikadocker/shudhkart:0.0.3 ./nodeserver"

# Change directory into appwrite-deployemnt
cd appwrite-deployment || exit 1

# Build nodeserver image
execute_command "docker compose down && docker compose up -d"

# Msg91 patch
execute_command "docker compose exec appwrite-worker-messaging sed -i 's#\[\$to\]#\$to#g' /usr/src/code/vendor/utopia-php/messaging/src/Utopia/Messaging/Adapters/SMS/Msg91.php && docker compose restart appwrite-worker-messaging"


