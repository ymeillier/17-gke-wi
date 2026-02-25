#!/bin/bash

# This script assigns a list of IAM roles to a user or service account at the project level.

# Usage:
# 1. Source this script: `source scripts/iam-policy-add-project.sh`
# 2. Call the function: `assign_project_roles "your-project-id" "account-email" "role1 role2 role3"`

assign_project_roles() {
    if [ "$#" -ne 3 ]; then
        echo "Usage: assign_project_roles <PROJECT_ID> <ACCOUNT> <ROLES_LIST>"
        echo "Example: assign_project_roles \"my-gcp-project\" \"user@example.com\" \"roles/viewer roles/storage.objectViewer\""
        return 1
    fi

    local PROJECT_ID="$1"
    local ACCOUNT="$2"
    local ROLES_LIST="$3"
    local member_type

    # Detect if the account is a user or a service account
    if [[ "$ACCOUNT" == *@*.gserviceaccount.com ]]; then
        member_type="serviceAccount"
    else
        member_type="user"
    fi

    echo "Assigning roles to $member_type: $ACCOUNT on project: $PROJECT_ID"

    # Convert the space-separated string of roles into an array
    read -r -a roles <<< "$ROLES_LIST"

    for role in "${roles[@]}"; do
        echo "Assigning role: $role"
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="$member_type:${ACCOUNT}" \
            --role="$role" \
            --condition=None # Explicitly set no condition
    done


    echo "All roles assigned successfully."
}
