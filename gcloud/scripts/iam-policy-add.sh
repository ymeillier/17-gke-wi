#!/bin/bash

#Entity:
ACCOUNT=admin@meillier.altostrat.com
#or for a service account:
ACCOUNT=service@gcp-sa-vmmigration.iam.gserviceaccount.com

#Roles:
ROLE="roles/owner"


declare -a roles=(
    "roles/owner"
    "roles/compute.viewer"
    "roles/container.viewer"
    "roles/gkehub.admin"
    "roles/gkehub.viewer"
    "roles/gkeonprem.admin"
    "roles/iam.securityAdmin"
    "roles/iam.serviceAccountAdmin"
    "roles/iam".serviceAccountKeyAdmin"
    "roles/iam.serviceAccountTokenCreator"
    "roles/logging.admin"
    "roles/monitoring.admin"
    "roles/monitoring.dashboardEditor "
    "roles/serviceusage.serviceUsageAdmin"
    "roles/storage.admin"
)

for role in "${roles[@]}
do
#user binding
gcloud projects add-iam-policy-binding $PROJECT_ID \
--member="user:${ACCOUNT}" \
--role="$ROLE"

#sa binding
gcloud projects add-iam-policy-binding $PROJECT_ID \
--member="serviceAccount:${ACCOUNT}" \
--role="$ROLE"
    
done


# #Folder
# ##FOLDER_ID=$ID_FOLDER_GDCV
# gcloud resource-manager folders add-iam-policy-binding $FOLDER_ID \
# --member="user:${ACCOUNT}" \
# --role="$ROLE"
# 
# gcloud resource-manager folders add-iam-policy-binding $FOLDER_ID \
# --member="serviceAccount:${ACCOUNT}" \
# --role="$ROLE"
# 
# # Organization
# ##ORG_ID=1061229561493
# gcloud organizations add-iam-policy-binding $ORG_ID \
# --member="user:${ACCOUNT}" \
# --role="$ROLE"
# 
# gcloud organizations add-iam-policy-binding $ORG_ID \
# --member="serviceAccount:${ACCOUNT}" \
# --role="$ROLE"
# 
# # SERVICE_ACCOUNT:
