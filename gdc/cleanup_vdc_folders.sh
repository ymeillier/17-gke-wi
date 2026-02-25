#!/bin/bash

# This script is designed to clean up Google Cloud resources.
# It identifies folders within a specified organization that match the pattern 'vdc-xxxx',
# where 'xxxx' represents a four-digit number.
#
# Usage: ./cleanup_vdc_folders.sh [-y]
#   -y: Automatically answer 'yes' to all prompts.
#
# For each matching folder, the script will:
# 1. Identify all projects directly within that folder.
# 2. Prompt the user for confirmation before deleting each project.
# 3. After processing the projects, prompt the user for confirmation to delete the folder.
#
# WARNING: This script performs destructive actions (deleting projects and folders).
# Ensure you have the correct permissions and have backed up any necessary data before execution.

# Set the organization ID
ORGANIZATION_ID="1061229561493"

# Check for -y flag
AUTO_CONFIRM=false
if [ "$1" == "-y" ]; then
    AUTO_CONFIRM=true
    echo "Auto-confirm mode enabled. All prompts will be answered with 'yes'."
fi

# Get all folder IDs matching the pattern vdc-*
echo "Fetching folders matching 'vdc-*' in organization $ORGANIZATION_ID..."
FOLDER_IDS=$(gcloud resource-manager folders list --organization="$ORGANIZATION_ID" --filter="displayName:vdc-*" --format="value(name.basename())")

if [ -z "$FOLDER_IDS" ]; then
    echo "No folders found matching the pattern."
    exit 0
fi

echo "Found the following folders to process:"
gcloud resource-manager folders list --organization="$ORGANIZATION_ID" --filter="displayName:vdc-*" --format="table(displayName, name.basename():label=ID)"
echo "---"

# Loop through each folder ID
for FOLDER_ID in $FOLDER_IDS; do
    FOLDER_NAME=$(gcloud resource-manager folders describe $FOLDER_ID --format="value(displayName)")
    echo "Processing folder: $FOLDER_NAME (ID: $FOLDER_ID)"

    # Get all project IDs in the current folder
    PROJECT_IDS=$(gcloud projects list --filter="parent.id=$FOLDER_ID" --format="value(projectId)")

    ALL_PROJECTS_MARKED_FOR_DELETION=true
    if [ -z "$PROJECT_IDS" ]; then
        echo "  No projects found in this folder."
    else
        # Loop through each project ID and ask for deletion confirmation
        for PROJECT_ID in $PROJECT_IDS; do
            if [ "$AUTO_CONFIRM" = true ]; then
                echo "  -> Auto-deleting project '$PROJECT_ID' in folder '$FOLDER_NAME'..."
                REPLY="y"
            else
                read -p "  -> Delete project '$PROJECT_ID' in folder '$FOLDER_NAME'? (y/N) " -n 1 -r
                echo # Move to a new line
            fi
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "     Deleting project '$PROJECT_ID'..."
                gcloud projects delete "$PROJECT_ID" --quiet
            else
                echo "     Skipping project deletion."
                ALL_PROJECTS_MARKED_FOR_DELETION=false
            fi
        done
    fi

    # Now, ask for folder deletion confirmation, but only if all projects were deleted.
    if [ "$ALL_PROJECTS_MARKED_FOR_DELETION" = true ]; then
        if [ "$AUTO_CONFIRM" = true ]; then
            echo "  -> All projects processed. Auto-deleting folder '$FOLDER_NAME'..."
            REPLY="y"
        else
            read -p "  -> All projects processed. Delete folder '$FOLDER_NAME'? (y/N) " -n 1 -r
            echo # Move to a new line
        fi

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "     Deleting folder '$FOLDER_NAME'..."
            gcloud resource-manager folders delete "$FOLDER_ID" --quiet
        else
            echo "     Skipping folder deletion."
        fi
    else
        echo "  Skipping deletion of folder '$FOLDER_NAME' because one or more projects within it were not deleted."
    fi
    echo "---"
done

echo "Script finished."
