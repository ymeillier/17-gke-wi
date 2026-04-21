#!/bin/bash
# Modify Argolis Policies that are too restrictive
# Note: Organization Policy Administrator IAM permissions are needed to run this script
# References:
# - https://cloud.google.com/sdk/gcloud/reference/beta/resource-manager
# - https://cloud.google.com/compute/docs/images/restricting-image-access#trusted_images
#
# USAGE: argolis-fix-policy-defaults.sh [PROJECT_ID]
# if no project is given, the current gcloud project is used
 
project=${1:-`gcloud config get-value project`}

declare -a policies=(
    "constraints/compute.trustedImageProjects"
    "constraints/compute.vmExternalIpAccess"
    "constraints/compute.restrictSharedVpcSubnetworks"
    "constraints/compute.restrictSharedVpcHostProjects"
    "constraints/compute.restrictVpcPeering"
    "constraints/compute.restrictVpnPeerIPs"
    "constraints/compute.vmCanIpForward"
    "constraints/essentialcontacts.allowedContactDomains"
    "constraints/iam.allowedPolicyMemberDomains"
    "constraints/compute.requireShieldedVm"
    "constraints/compute.requireOsLogin"
    "constraints/iam.disableServiceAccountKeyCreation"
    "constraints/iam.disableServiceAccountCreation"
    "constraints/compute.skipDefaultNetworkCreation"
    "constraints/compute.disableVpcExternalIpv6"
    "constraints/compute.disableSerialPortAccess"
)

for policy in "${policies[@]}"
do
    gcloud org-policies reset $policy --project=$project
done



# Explicitly disable the enforcement of  the disable-auto-grants policy
# This ensures default SAs do NOT get the Editor role
# without the below policy being disabled, the GCE service account used by default by GKE cluster would not have the required permissions to do its jobs such as sending logs...
# https://cloud.google.com/blog/products/identity-security/introducing-stronger-default-org-policies-for-our-customers
gcloud org-policies set-policy - <<EOF
name: projects/$project/policies/iam.automaticIamGrantsForDefaultServiceAccounts
spec:
  rules:
  - enforce: false
EOF

# #To check:
# gcloud resource-manager org-policies describe \
#     iam.automaticIamGrantsForDefaultServiceAccounts \
#     --project=$PROJECT_ID \
#     --effective
