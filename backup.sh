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


# Change directory into nodeserver
cd appwrite-deployment || exit 1


# Create dump.sql file
MARIADB_USER=$(find_var "MARIADB_USER" "$@")
echo $MARIADB_USER

MARIADB_PASSWORD=$(find_var "MARIADB_PASSWORD" "$@")
echo $MARIADB_PASSWORD
execute_command 'docker compose exec mariadb   sh -c   "exec mysqldump --all-databases --add-drop-database -u\"$MARIADB_USER\" -p\"$MARIADB_PASSWORD\"" > ./dump.sql'


# Clone nodeserver
current_timestamp=$(date +%s)
BACKBLAZE_B2_KEY_ID=$(find_var "BACKBLAZE_B2_KEY_ID" "$@")
BACKBLAZE_B2_KEY=$(find_var "BACKBLAZE_B2_KEY" "$@")
BUCKET_NAME=$(find_var "BUCKET_NAME" "$@")
execute_command 'docker run   --rm   -v $PWD:/b2   mtronix/b2-cli:0.0.1   bash -c   "b2 authorize-account $BACKBLAZE_B2_KEY_ID $BACKBLAZE_B2_KEY && b2 upload-file $BUCKET_NAME dump.sql dump_$current_timestamp.sql"'


# remove dump file
execute_command "rm dump.sql"


# backup influxdb
execute_command 'docker compose exec influxdb   sh -c   "influxd backup --portable /storage/influxdb-backup_$current_timestamp"'

# copy influxdb backup to local
execute_command 'docker cp appwrite-influxdb:/storage/influxdb-backup_$current_timestamp ./'

# create tar.gz of influxdb backup
execute_command 'tar -czvf influxdb-backup_$current_timestamp.tar.gz influxdb-backup_$current_timestamp/'

# upload influxdb backup tar.gz to backblaze
execute_command 'docker run   --rm   -v $PWD:/b2   mtronix/b2-cli:0.0.1   bash -c   "b2 authorize-account $BACKBLAZE_B2_KEY_ID $BACKBLAZE_B2_KEY && b2 upload-file $BUCKET_NAME influxdb-backup_$current_timestamp.tar.gz influxdb-backup_$current_timestamp.tar.gz"'

# backup influxdb
execute_command 'docker compose exec influxdb   sh -c   "rm -r /storage/influxdb-backup_$current_timestamp"'

# remove backup files
execute_command "rm influxdb-backup_$current_timestamp.tar.gz && rm -r influxdb-backup_$current_timestamp.tar.gz"