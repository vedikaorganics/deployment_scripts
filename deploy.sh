#!/bin/bash

GITHUB_PAT=""


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

# Check if no arguments are passed
if [ $# -eq 0 ]; then
    echo "Error: No arguments provided. Please provide environment variable and value pairs."
    exit 1
fi

# Commands on the DigitalOcean droplet

# Clone nodeserver
execute_command "git clone https://vedikaorganics:${GITHUB_PAT}@github.com/vedikaorganics/nodeserver.git"

# Build nodeserver image
execute_command "docker build -t vedikadocker/shudhkart:0.0.3 ./nodeserver"

# Clone appwrite-deployment
execute_command "git clone https://vedikaorganics:${GITHUB_PAT}@github.com/vedikaorganics/appwrite-deployment.git"

# Change directory into appwrite-deployment
cd appwrite-deployment || exit 1

# Make update_env.sh executable
execute_command "chmod +x update_env.sh"

# Update .env variables
for arg in "$@"; do
    execute_command "./update_env.sh $arg"
done

# Start up docker compose
execute_command "docker compose up -d --remove-orphans"

# Apply the patch for appwrite msg91 bug
execute_command "docker compose exec appwrite-worker-messaging sed -i 's#\[$to\]#$to#g' /usr/src/code/vendor/utopia-php/messaging/src/Utopia/Messaging/Adapters/SMS/Msg91.php && docker compose restart appwrite-worker-messaging"

# generate certificate
execute_command "docker compose exec appwrite ssl domain='testbackend.vedikaorganics.com'"

# wait some time for container init completion
echo "waiting..."
for ((i=1; i<=60; i++)); do
    echo "Waiting... $i seconds"
    sleep 1
done
echo "proceeding for project setup"

# run python scripts to create project
cd .. || exit 1
cd python_scripts
execute_command "apt-get remove -y needrestart"
execute_command "apt install -y python3-pip"
execute_command "pip3 install -r requirements.txt"
execute_command "python3 create_project.py"

# # edit appwrite keys in .env and restart server
cd .. || exit 1
cd appwrite-deployment
execute_command "chmod +x update_env.sh"
execute_command "./update_env.sh `cat .appwrite_keys`"
execute_command "docker compose down"
execute_command "docker compose up -d --remove-orphans"
execute_command "docker compose exec appwrite-worker-messaging sed -i 's#\[$to\]#$to#g' /usr/src/code/vendor/utopia-php/messaging/src/Utopia/Messaging/Adapters/SMS/Msg91.php && docker compose restart appwrite-worker-messaging"


