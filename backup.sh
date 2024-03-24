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
cd appwrite-deployment || exit 1


# Build nodeserver image
execute_command 'docker compose exec mariadb   sh -c   'exec mysqldump --all-databases --add-drop-database -u"$MARIADB_USER" -p"$MARIADB_PASSWORD"' > ./dump.sql'


# Clone nodeserver
current_timestamp=$(date +%s)
execute_command 'docker run   --rm   -v $PWD:/b2   mtronix/b2-cli:0.0.1   bash -c   "b2 authorize-account $BACKBLAZE_B2_KEY_ID BACKBLAZE_B2_KEY && b2 upload-file $BUCKET_NAME dump.sql dump_$current_timestamp.sql"'


# Build nodeserver image
execute_command "rm dump.sql"