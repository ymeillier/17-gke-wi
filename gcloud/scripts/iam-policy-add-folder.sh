#!/bin/bash

# This script assigns a list of IAM roles to a user or service account at the folder level.

# Usage:
# declare -a my_roles=("roles/viewer" "roles/editor" ...)
# or
# declare -a roles=(
#     "roles/owner"
#     "roles/compute.viewer"
#     "roles/container.viewer"
#     "roles/gkehub.admin"
#     "roles/gkehub.viewer"
#     "roles/gkeonprem.admin"
#     "roles/iam.securityAdmin"
#     "roles/iam.serviceAccountAdmin"
#     "roles/iam".serviceAccountKeyAdmin"
#     "roles/iam.serviceAccountTokenCreator"
#     "roles/logging.admin"
#     "roles/monitoring.admin"
#     "roles/monitoring.dashboardEditor "
#     "roles/serviceusage.serviceUsageAdmin"
#     "roles/storage.admin"
# )

# ./scripts/iam-policy-add-folder.sh "your-folder-id" "user:account-email" "${my_roles[@]}"
#or for service account
# ./scripts/iam-policy-add-folder.sh "your-folder-id" "serviceAccount:sa-email" "${my_roles[@]}"

# IF user does not invoke the function with the right number of arguments:
if [ "$#" -lt 3 ]; then
    echo "⚠️"
    echo "Usage: $0 <PROJECT_ID> <ACCOUNT> <ROLE_1> [<ROLE_2> ...]"
    echo "Example: $0 \"my-folder-id\" \"user:user@example.com\" \"roles/viewer\" \"roles/storage.objectViewer\""
    echo "Example: $0 \"my-folder-id\" \"serviceAccount:sa@xyz.gserviceaccount.com\" \"roles/viewer\" \"roles/storage.objectViewer\""
    exit 1
fi

FOLDER_ID="$1"
MEMBER="$2"
# All arguments from the 3rd one are considered roles
roles=("${@:3}")

echo "Assigning roles to $MEMBER on folder: $FOLDER_ID"

for role in "${roles[@]}"; do
    echo "🔄 Assigning role: $role"

    gcloud resource-manager folders add-iam-policy-binding $FOLDER_ID \
        --member="${MEMBER}" \
        --role="$role" \
        --condition=None # Explicitly set no condition
done

echo "✅ All roles assigned successfully."

# Direct
# gcloud projects get-iam-policy $FOLDER_ID \
# --flatten bindings[].members \
# --filter bindings.members:$MEMBER \
# --format="table[box](bindings.role,bindings.members)"

# Inherited
gcloud config set accessibility/screen_reader false

gcloud resource-manager folders get-ancestors-iam-policy $FOLDER_ID \
--flatten policy.bindings[].members \
--filter policy.bindings.members:$MEMBER \
--format="table[box](policy.bindings.role,policy.bindings.members,id)"
