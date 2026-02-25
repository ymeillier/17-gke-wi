#!/bin/bash
# Run with --auto-approve flag to skip manual proceeding checks. 

# Define color codes for output
GREEN_BOLD='\033[1;32m'
BLUE_BOLD='\033[1;34m'
RED_BOLD='\033[1;31m'
NO_COLOR='\033[0m'

VARS_FILE="./.variables"

# 1. Load Variables
if [ -f "$VARS_FILE" ]; then
    printf "ℹ️  Loading variables from $VARS_FILE\n"
    source "$VARS_FILE"
else
    printf "❌ Error: $VARS_FILE not found. Cannot proceed with cleanup.\n"
    exit 1
fi

# Ensure necessary variables are set
if [[ -z "$PROJECT_ID" || -z "$FOLDER_ID" ]]; then
    printf "❌ Error: Missing critical variables (PROJECT_ID, or FOLDER_ID) in $VARS_FILE.\n"
    exit 1
fi

printf "\n🚀 Starting Cleanup for Project: ${GREEN_BOLD}$PROJECT_ID${NO_COLOR}\n"


# 2. Delete Project
# Deleting the project will remove all resources contained within it (VPCs, Subnets, VMs, IAM bindings on the project, etc.)
printf "\n▶️  Step: ${BLUE_BOLD}Deleting Project: $PROJECT_ID${NO_COLOR}\n"

# Check if project exists
if gcloud projects describe "$PROJECT_ID" > /dev/null 2>&1; then
    gcloud projects delete "$PROJECT_ID" --quiet
    printf "    ✅ Project $PROJECT_ID deleted.\n"
else
    printf "    ⚠️  Project $PROJECT_ID not found or already deleted.\n"
fi


# 2.1 Delete Fleet Project (if exists)
if [[ -n "$PROJECT_ID_FLEET" ]]; then
    printf "\n▶️  Step: ${BLUE_BOLD}Deleting Fleet Project: $PROJECT_ID_FLEET${NO_COLOR}\n"

    # Check if project exists
    if gcloud projects describe "$PROJECT_ID_FLEET" > /dev/null 2>&1; then
        gcloud projects delete "$PROJECT_ID_FLEET" --quiet
        printf "    ✅ Project $PROJECT_ID_FLEET deleted.\n"
    else
        printf "    ⚠️  Project $PROJECT_ID_FLEET not found or already deleted.\n"
    fi
else
    printf "\nℹ️  No PROJECT_ID_FLEET found in variables. Skipping fleet project cleanup.\n"
fi


# 3. Delete Folder
# Folders can only be deleted if they contain no active projects (lifecycle state DELETE_REQUESTED is fine).
# We might need to wait for the project deletion to propagate, but usually, it's quick enough or we can retry.
if [[ -n "$FOLDER_ID" ]]; then
    printf "\n▶️  Step: ${BLUE_BOLD}Deleting Folder: $FOLDER_ID${NO_COLOR}\n"
    
    # Simple retry mechanism if folder deletion fails due to lingering resources
    MAX_RETRIES=3
    count=0
    while [ $count -lt $MAX_RETRIES ]; do
        if gcloud resource-manager folders delete "$FOLDER_ID" --quiet 2>/dev/null; then
            printf "    ✅ Folder $FOLDER_ID deleted.\n"
            break
        else
            if [ $count -eq $((MAX_RETRIES - 1)) ]; then
                 printf "    ⚠️  Failed to delete folder $FOLDER_ID immediately. It might still contain the project in a 'pending deletion' state.\n"
                 printf "        You may need to delete it manually later: gcloud resource-manager folders delete $FOLDER_ID\n"
            else
                 printf "    ⏳ Waiting for project deletion to register... (Attempt $((count+1))/$MAX_RETRIES)\n"
                 sleep 5
            fi
        fi
        count=$((count+1))
    done
fi

# 4. Local File Cleanup
printf "\n▶️  Step: ${BLUE_BOLD}Cleaning up local configuration files${NO_COLOR}\n"

cp $VARS_FILE .saved_var_file

files_to_remove=(
    "$VARS_FILE"
    ".project-name-prefix"
    ".random-suffix"
    "../.assets-execution-code"
)

for file in "${files_to_remove[@]}"; do
    if [ -f "$file" ]; then
        rm "$file"
        printf "    🗑️  Removed $file\n"
    fi
done

# 5. Unset gcloud config
# If the current active project was the one we just deleted, unset it to avoid confusion.
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [[ "$CURRENT_PROJECT" == "$PROJECT_ID" ]]; then
    printf "\n▶️  Step: ${BLUE_BOLD}Unsetting active gcloud project${NO_COLOR}\n"
    gcloud config unset project
    printf "    ✅ Active project unset.\n"
fi

printf "\n🎉 ${GREEN_BOLD}Cleanup Complete!${NO_COLOR}\n"
