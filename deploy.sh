#!/bin/bash

find_var() {
    local allowed_origin_input="$1"
    local found=false
    local arg
    local allowed_origin_value

    # Iterate through all positional arguments
    for arg in "${@:2}"; do
        # Check if the argument is "ALLOWED_ORIGIN"
        if [[ "$arg" == "$allowed_origin_input="* ]]; then
            # Extract the value of ALLOWED_ORIGIN (removing the prefix)
            allowed_origin_value="${arg#$allowed_origin_input=}"
            found=true
            break  # Exit loop after finding ALLOWED_ORIGIN
        fi
    done

    # If ALLOWED_ORIGIN was not found, exit the script
    if ! $found; then
        echo "$allowed_origin_input not found."
        exit 1
    fi

    echo "$allowed_origin_value"
}
# ALLOWED_ORIGIN=$(find_allowed_origin "EMAIL_BOT_NAME" "$@")
# echo "ALLOWED_ORIGIN found: $ALLOWED_ORIGIN"


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

GITHUB_KEY=$(find_var "GITHUB_KEY" "$@")

# Clone nodeserver
execute_command "git clone https://vedikaorganics:${GITHUB_KEY}@github.com/vedikaorganics/nodeserver.git"

# Build nodeserver image
execute_command "docker build -t vedikadocker/shudhkart:0.0.3 ./nodeserver"

# Clone appwrite-deployment
execute_command "git clone https://vedikaorganics:${GITHUB_KEY}@github.com/vedikaorganics/appwrite-deployment.git"

# Change directory into appwrite-deployment
cd appwrite-deployment || exit 1

# Make update_env.py executable
# execute_command "chmod +x update_env.py"

# Update .env variables
for arg in "$@"; do
    execute_command "python3 update_env.py $arg"
done

# Start up docker compose
execute_command "docker compose up -d --remove-orphans"

# Apply the patch for appwrite msg91 bug
execute_command "docker compose exec appwrite-worker-messaging sed -i 's#\[\$to\]#\$to#g' /usr/src/code/vendor/utopia-php/messaging/src/Utopia/Messaging/Adapters/SMS/Msg91.php && docker compose restart appwrite-worker-messaging"

# generate certificate
_APP_DOMAIN=$(find_var "_APP_DOMAIN" "$@")
execute_command "docker compose exec appwrite ssl domain='${_APP_DOMAIN}'"

# wait some time for container init completion
echo "waiting..."
# Define variables
DB_CONTAINER_NAME="appwrite-mariadb"
DB_USER="user"
DB_PASSWORD="password"
MAX_TRIES=60
SLEEP_INTERVAL=2

# Function to check if MariaDB is ready
wait_for_mariadb() {
    echo "Waiting for MariaDB to become ready..."
    for ((i=0; i<$MAX_TRIES; i++)); do
        if docker exec "$DB_CONTAINER_NAME" mysql -u"$DB_USER" -p"$DB_PASSWORD" -e "exit"; then
            echo "MariaDB is ready for connections"
            break
        fi
        sleep $SLEEP_INTERVAL
    done
    echo "Timed out waiting for MariaDB to become ready"
}


wait_for_mariadb
echo "Proceeding for project setup"

# run python scripts to create project
CLIENT_HOST=$(find_var "CLIENT_HOST" "$@")
cd .. || exit 1
cd python_scripts
# execute_command "apt-get remove -y needrestart"
# execute_command "apt install -y python3-pip"
execute_command "pip3 install -r requirements.txt"
execute_command "python3 create_project.py ${CLIENT_HOST}"

# # edit appwrite keys in .env and restart server
cd .. || exit 1
cd appwrite-deployment
execute_command "python3 update_env.py `cat .appwrite_keys`"
execute_command "docker compose down"
execute_command "docker compose up -d --remove-orphans"
execute_command "docker compose exec appwrite-worker-messaging sed -i 's#\[\$to\]#\$to#g' /usr/src/code/vendor/utopia-php/messaging/src/Utopia/Messaging/Adapters/SMS/Msg91.php && docker compose restart appwrite-worker-messaging"


