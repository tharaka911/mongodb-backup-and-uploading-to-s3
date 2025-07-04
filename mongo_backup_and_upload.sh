#!/bin/bash

# ============================
# MongoDB Backup and S3 Upload
# ============================


ENV_FILE="./.env" # Path to the environment file

if [ -f "$ENV_FILE" ]; then
    echo "Loading environment variables from $ENV_FILE"
    set -o allexport # Automatically export all variables defined after this point
    source "$ENV_FILE"
    set +o allexport # Turn off auto-export
else
    echo "Error: Environment file '$ENV_FILE' not found!"
    echo "Please create it with your sensitive configuration variables."
    exit 1
fi

# --- Validate essential variables are set ---
if [ -z "$MONGO_URI" ] || \
   [ -z "$S3_BUCKET" ] || \
   [ -z "$PROJECT_NAME" ] || \
   [ -z "$BACKUP_PARENT_DIR" ]; then
    echo "Error: Missing essential environment variables in $ENV_FILE."
    echo "Required: MONGO_URI, S3_BUCKET, PROJECT_NAME, BACKUP_PARENT_DIR."
    exit 1
fi

# --------- Derived Variables ---------
NOW=$(date +"%Y-%m-%d-%H-%M-%S") # Added seconds for more unique timestamps
FOLDER_NAME="${PROJECT_NAME}-$NOW"
BACKUP_DIR="$BACKUP_PARENT_DIR/$FOLDER_NAME"
ZIP_FILE="$BACKUP_PARENT_DIR/$FOLDER_NAME.zip"
LOG_FILE="$BACKUP_PARENT_DIR/backup_log.txt" # Log file path can remain static per execution instance

S3_PATH="backups/$FOLDER_NAME.zip" # Path inside the S3 bucket

# -------- Helper Functions --------
log_section() {
    echo "----------------------------------------" | tee -a "$LOG_FILE"
}

log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") | $1" | tee -a "$LOG_FILE"
}

step_timing() {
    local label="$1"
    local start="$2"
    local end="$3"
    local duration=$((end - start))
    local h=$(($duration/3600))
    local m=$((($duration%3600)/60))
    local s=$(($duration%60))
    log "$label took $duration seconds (${h}h ${m}m ${s}s)"
}

# -------- Start Script --------
SCRIPT_START=$(date +%s)
log_section
log "===== MongoDB Backup Script Started ====="
log "Project Name: $PROJECT_NAME"
log "Backup Target S3 Bucket: $S3_BUCKET"

# Step 1: Create backup directory
STEP1_START=$(date +%s)
log_section
log "Step 1: Creating backup directory..."
mkdir -p "$BACKUP_DIR"
if [ $? -ne 0 ]; then
    log "Failed to create backup directory: $BACKUP_DIR"
    exit 1
fi
log "Created backup directory: $BACKUP_DIR"
STEP1_END=$(date +%s)
step_timing "Step 1 (Create backup directory)" $STEP1_START $STEP1_END

# Step 2: Run mongodump
STEP2_START=$(date +%s)
log_section
log "Step 2: Starting MongoDB backup..."
# Pass AUTH_DB if it's set, otherwise omit the flag
if [ -n "$MONGO_AUTH_DB" ]; then
    mongodump --uri="$MONGO_URI" --authenticationDatabase "$MONGO_AUTH_DB" --out "$BACKUP_DIR" --readPreference primary
else
    mongodump --uri="$MONGO_URI" --out "$BACKUP_DIR" --readPreference primary
fi

if [ $? -ne 0 ]; then
    log "MongoDB backup failed!"
    exit 1
fi
log "MongoDB backup completed successfully at: $BACKUP_DIR"
STEP2_END=$(date +%s)
step_timing "Step 2 (MongoDB backup)" $STEP2_START $STEP2_END

# Step 3: Zip the backup folder
STEP3_START=$(date +%s)
log_section
log "Step 3: Zipping backup folder..."
cd "$BACKUP_PARENT_DIR" || { log "Failed to change directory to $BACKUP_PARENT_DIR"; exit 1; }
zip -r "$ZIP_FILE" "$FOLDER_NAME" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    log "Failed to zip backup folder: $ZIP_FILE"
    exit 1
fi
log "Backup folder zipped as: $ZIP_FILE"
STEP3_END=$(date +%s)
step_timing "Step 3 (Zip backup folder)" $STEP3_START $STEP3_END

# Step 4: Upload to AWS S3
STEP4_START=$(date +%s)
log_section
log "Step 4: Uploading backup zip to S3: s3://$S3_BUCKET/$S3_PATH"
if [ -n "$AWS_PROFILE" ]; then
    aws s3 cp "$ZIP_FILE" "s3://$S3_BUCKET/$S3_PATH" --profile "$AWS_PROFILE"
else
    # Fallback if no AWS_PROFILE, assumes AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are in env
    aws s3 cp "$ZIP_FILE" "s3://$S3_BUCKET/$S3_PATH"
fi

if [ $? -ne 0 ]; then
    log "Failed to upload $ZIP_FILE to S3!"
    exit 1
fi
log "Backup zip uploaded to S3 successfully."
STEP4_END=$(date +%s)
step_timing "Step 4 (Upload to S3)" $STEP4_START $STEP4_END

# Step 5: Cleanup
STEP5_START=$(date +%s)
log_section
log "Step 5: Cleaning up backup files..."
rm -rf "$BACKUP_DIR"
rm -f "$ZIP_FILE"
if [ $? -ne 0 ]; then
    log "Cleanup failed! Please check manually."
    # We might not want to exit here if cleanup fails, as the backup is already done
    # exit 1
fi
log "Cleanup completed. Removed $BACKUP_DIR and $ZIP_FILE."
STEP5_END=$(date +%s)
step_timing "Step 5 (Cleanup)" $STEP5_START $STEP5_END

# Script end
SCRIPT_END=$(date +%s)
log_section
step_timing "Total script execution time" $SCRIPT_START $SCRIPT_END
log "===== MongoDB Backup Script Finished Successfully ====="
log_section

exit 0