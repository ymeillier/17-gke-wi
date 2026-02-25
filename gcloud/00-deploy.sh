#!/bin/bash



############################################################################################################
############################################################################################################
# Argument Parsing
AUTO_APPROVE="false"
for arg in "$@"; do
    case $arg in
        -y|-Y|--auto-approve)
            AUTO_APPROVE="true"
            shift
            ;;
    esac
done

if [[ "$AUTO_APPROVE" == "false" ]]; then
    printf "\n"
    printf "ℹ️  No auto-approve flag provided.\n"
    read -r -p "   Do you want to run with auto-approve enabled? (y/N): " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        AUTO_APPROVE="true"
        printf "   ✅ Auto-approve enabled via prompt.\n"
    else
        printf "   running in manual mode (press Enter to continue steps).\n"
    fi
    printf "\n"
fi



## Variable Persistence Setup

VARS_FILE="./.variables"

# Function to save variables to file and export them
save_var() {
    local var_name="$1"
    local var_value="$2"
    
    # 1. Export in current session
    export "${var_name}"="${var_value}"
    
    # 2. Save to file (removing old value if present to keep file clean)
    if [ ! -f "$VARS_FILE" ]; then
        touch "$VARS_FILE"
    fi
    
    # Use a temporary file to filter out the old variable definition
    grep -v "^export ${var_name}=" "$VARS_FILE" > "${VARS_FILE}.tmp"
    mv "${VARS_FILE}.tmp" "$VARS_FILE"
    
    echo "export ${var_name}=\"${var_value}\"" >> "$VARS_FILE"
}

# Source existing variables if file exists
if [ -f "$VARS_FILE" ]; then
    printf "    ℹ️  Loading existing variables from $VARS_FILE\n"
    source "$VARS_FILE"
fi

# Create execution tracking file in parent directory
echo "00-deploy.sh" > "$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"/.assets-execution-code

############################################################################################################
############################################################################################################
## Unique, Script specific configurations
# Variables dictating how many VPCs (prod, dev, prod2) and regions (vpc subnets in those) per vpc to create
save_var NUM_VPCS "1" # 1 to 3
save_var NUM_REGIONS "1" # 1 to 3

#Parent: 
save_var ORGANIZATION_ID "1061229561493" # Your Organization ID
#save_var FOLDER_PARENT "organization/$ORGANIZATION_ID" # Parent for the new folder
## OR
save_var FOLDER_PARENT "folder/199746281786" # Uncomment this line and comment above if using a folder as parent
## gcloud resource-manager folders list --organization 1061229561493
##      DISPLAY_NAME        PARENT_NAME                             ID
##      00-prototyping-gke  organizations/1061229561493   199746281786

# NEW FOLDER
save_var FOLDER_NAME_SUFFIX "$(basename "$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")")" # Suffix for the folder name (e.g., gke-prototyping-XXXXX)


############################################################################################################
############################################################################################################
## Reusable Configurations

# Authentication
save_var USER_ACCOUNT "admin@meillier.altostrat.com" # The user account to perform operations as







## PROJECT_NAME_PREFIX Handling
## Script will check for the presence of the file .project-name-prefix. 
## IF it does not exist, the project name suffix will be defined here either by specifying the name or using the script parent folder name if left undefined.


# save_var PROJECT_NAME_PREFIX "gke-lab" # Uncomment this line if want to hardcode the project name
PREFIX_FILE=".project-name-prefix"
if [ -f "$PREFIX_FILE" ]; then
    # 1. Read from file if it exists
    save_var PROJECT_NAME_PREFIX "$(cat "$PREFIX_FILE")"
    printf "    ℹ️  Reusing existing project prefix from file: \033[1;31m$PROJECT_NAME_PREFIX\033[0m\n"
else
    # 2. If not in file, check if already set (e.g. manually in this script)
    if [[ -z "${PROJECT_NAME_PREFIX}" ]]; then
        # 3. If not set, use "project"
        save_var PROJECT_NAME_PREFIX "project"
        printf "    ℹ️  PROJECT_NAME_PREFIX not set. Using default: \033[1;31m$PROJECT_NAME_PREFIX\033[0m\n"
    else
        save_var PROJECT_NAME_PREFIX "${PROJECT_NAME_PREFIX}"
        printf "    ℹ️  Using manually defined PROJECT_NAME_PREFIX: \033[1;31m$PROJECT_NAME_PREFIX\033[0m\n"
    fi
    # Save for future consistency
    echo "$PROJECT_NAME_PREFIX" > "$PREFIX_FILE"
    printf "        (Saved prefix to $PREFIX_FILE for consistency)\n"
fi

# Generate or reuse random suffix for uniqueness to allow re-running the script
SUFFIX_FILE=".random-suffix"
if [ -f "$SUFFIX_FILE" ]; then
    save_var RANDOM_SUFFIX "$(cat "$SUFFIX_FILE")"
    printf "    ℹ️  Reusing existing random suffix from file: \033[1;31m$RANDOM_SUFFIX\033[0m\n"
else
    save_var RANDOM_SUFFIX "$(printf "%05d" $((RANDOM % 100000)))"
    echo "$RANDOM_SUFFIX" > "$SUFFIX_FILE"
    printf "    ℹ️  Generated new random suffix: \033[1;31m$RANDOM_SUFFIX\033[0m (saved to $SUFFIX_FILE)\n"
fi



# ## Network (VPC) Settings:
# save_var VPC_NAME "vpc-main"
# 
#
# save_var SUBNET_NAME_USC1 "subnet-us-central1"
# save_var SUBNET_REGION_USC1 "us-central1"
# save_var SUBNET_RANGE_USC1 "10.128.0.0/20" # to 10.128.15.254 = 4094 hosts
# save_var POD_RANGE_USC1 "192.168.0.0/18"  #  64 /24s
# save_var POD_RANGE_NAME_USC1 "pods-us-central1"
# save_var SVC_RANGE_USC1 "172.16.0.0/18"   #  16382 IPs  
# save_var SVC_RANGE_NAME_USC1 "svc-us-central1"
# 
# save_var SUBNET_NAME_USW1 "subnet-us-west1"
# save_var SUBNET_REGION_USW1 "us-west1"
# save_var SUBNET_RANGE_USW1 "10.128.64.0/20" # to 10.128.79.254 = 4094 hosts
# save_var POD_RANGE_USW1 "192.168.64.0/18"
# save_var POD_RANGE_NAME_USW1 "pods-us-west1"
# save_var SVC_RANGE_USW1 "172.16.64.0/18"
# save_var SVC_RANGE_NAME_USW1 "svc-us-west1"





# ## GKE Cluster Settings: (Commented out legacy settings)
# # save_var GKE_1_CLUSTER_NAME "gke-usc1"
# # save_var GKE_2_CLUSTER_NAME "gke-usw2"
# # ...







#     --location "$GKE_CP_REGION_OR_ZONE" \ 
        # (formerly --region) | or  --zone for zonal cluster but can use a zone as --location [https://docs.cloud.google.com/sdk/gcloud/reference/container/clusters/create#--location]
#     --node-locations "$GKE_NODES_ZONES" \
        #If not specified, all nodes will be in the cluster's primary zone (for zonal clusters) or spread across three randomly chosen zones within the cluster's region (for regional clusters)
        #Zonal Cluster: The control plane (master) is located in a single zone. By default, the nodes are also in that same zone.
        #Regional Cluster: The control plane is replicated across three zones in a region ( Creating a zonal clust...).
        #Multi-zonal Cluster: This is a specific type of zonal cluster. The control plane is still in one zone, but you use the --node-locations flag to spread your nodes across additional zones for better availability ( Creating a zonal clust...).
#
#     --release-channel "$GKE_RELEASE_CHANNEL" \ #rapid, regular*, stable, or None  (*: if no --cluster-version; --no-enable-autoupgrade; and --no-enable-autorepair )
#     --cluster-version $VERSION
        ##List available versions per channel:
        ##          gcloud container get-server-config --region us-central1 --format="yaml(channels)"
        ##
        ##          gcloud container get-server-config \
        ##            --region us-central1 \
        ##            --format="yaml(validMasterVersions)"



























############################################################################################################
############################################################################################################
## 0. Pre-Reqs

    # ANSI escape code for colored text:
    GREEN_NORMAL='\033[0;32m'
    GREEN_BOLD='\033[1;32m'
    BLUE_NORMAL='\033[0;34m'
    BLUE_BOLD='\033[1;34m'
    YELLOW_NORMAL='\033[0;33m'
    YELLOW_BOLD='\033[0;33m'
    RED_NORMAL='\033[0;31m'
    RED_BOLD='\033[1;31m'
    NO_COLOR='\033[0m'



    #clear
    printf '\nℹ️ \033[1;33m This bash script (main.sh) sets up the foundation constructs for experimentations.\033[0mℹ️\n'
    printf "    ℹ️  Using Random Suffix: \033[1;31m$RANDOM_SUFFIX\033[0m\n"
    printf "    ℹ️  Using Project Prefix: \033[1;31m$PROJECT_NAME_PREFIX\033[0m\n"
#

































############################################################################################################
############################################################################################################
## 1. Authentication

    printf '\n'
    printf "▶️  Step: \033[1;32m'Authentication Setup'\033[0m\n"

    printf "    🔑 Setting gcloud account to \033[1;32m'$USER_ACCOUNT'\033[0m...\n"
    gcloud config set account "$USER_ACCOUNT" > /dev/null 2>&1


    # Verify active account
    CURRENT_ACCOUNT=$(gcloud config get-value account 2>/dev/null)
    if [[ "$CURRENT_ACCOUNT" != "$USER_ACCOUNT" ]]; then
        printf "    ⚠️  \033[1;31mWARNING: Active account ($CURRENT_ACCOUNT) does not match USER_ACCOUNT ($USER_ACCOUNT).\033[0m\n"
        printf "        Attempting to login...\n"
        # Try to login or warn user they need to be logged in
        # Non-interactive scripts should ideally assume auth is done or use service account key, 
        # but for user scripts we can hint.
        echo "Please run: gcloud auth login $USER_ACCOUNT"
    else
        printf "    ✅ Active gcloud account confirmed: \033[1;32m%s\033[0m\n" "$USER_ACCOUNT"
    fi

    printf "    ✅ Authenticated user ${RED_NORMAL}'${USER_ACCOUNT}'\033[0m. Press Enter to Continue\n"
    if [[ "$AUTO_APPROVE" != "true" ]]; then
        read -r -p ""
    fi

    # Reset project and billing quota project to avoid issues with previous configurations
    printf "    🧹 Clearing project and billing/quota_project from gcloud config...\n"
    gcloud config unset project
    gcloud config unset billing/quota_project
#



































############################################################################################################
############################################################################################################
## 2. ORG level IAM Permissions: verify that user is an org admin.



    ## 2. Organization IAM Configuration

    printf '\n'
    printf "▶️  Step: ${GREEN_BOLD}'Organization IAM Configuration'\033[0m\n"

    # Roles required at the Org/Parent Folder level to create resources

    # #Service needed for running ./scripts/iam-policy-add-org.sh
    # declare -a apis=(
    #     "cloudresourcemanager.googleapis.com"
    # )
    # for api in "${apis[@]}"; do
    #     printf "    Enabling: \033[1;34m$api\033[0m on project $PROJECT_ID...\n"
    #     gcloud services enable "$api" --project "$PROJECT_ID" --async
    #     echo "Waiting for $api serive to be ACTIVE..."
    #     # Loop until the service appears in the 'enabled' list
    #     while [[ -z $(gcloud services list --enabled --filter="config.name:$api" --format="value(config.name)" --project="$PROJECT_ID") ]]; do
    #         echo "Current Status: PENDING... (checking again in 2 seconds)"
    #         sleep 2
    #     done
    # done


    declare -a ORG_IAM_ROLES=(
        "roles/resourcemanager.folderCreator" # To create folders
        #"roles/resourcemanager.projectCreator" # To create projects
        #"roles/billing.user" # To link billing accounts
        "roles/iam.securityAdmin" # To assign IAM policies
    )

    if [[ "$FOLDER_PARENT" == organization/* ]]; then
        PARENT_ID="${FOLDER_PARENT#organization/}"
        printf "    Assigning permissions to user ${BLUE_NORMAL} $USER_ACCOUNT\033[0m on Organization ${YELLOW_BOLD} $PARENT_ID\033[0m...\n"
        ./scripts/iam-policy-add-org.sh "$PARENT_ID" "user:$USER_ACCOUNT" "${ORG_IAM_ROLES[@]}"
        
    elif [[ "$FOLDER_PARENT" == folder/* ]]; then
        PARENT_ID="${FOLDER_PARENT#folder/}"
        printf "    Assigning permissions to user ${BLUE_NORMAL} $USER_ACCOUNT\033[0m on Folder ${YELLOW_BOLD} $PARENT_ID\033[0m...\n"
        # Using folder helper script
        ./scripts/iam-policy-add-folder.sh "$PARENT_ID" "user:$USER_ACCOUNT" "${ORG_IAM_ROLES[@]}"
    else
        printf "    ⚠️  Unknown parent type for IAM assignment. Skipping automatic role assignment.\n"
    fi

    printf "    ✅ Organization/ParentFolder folder creator IAM setup complete. Press Enter to Continue"
    if [[ "$AUTO_APPROVE" != "true" ]]; then
        read -r -p ""
    fi
#
























############################################################################################################
############################################################################################################
## 3. Folder Setup (GCP Folder matching OSX Folder name)

    # ## .1 Setup Required Services & IAM
    # printf '\n'
    # printf "▶️  Step: ${GREEN_BOLD} Enable Services ${NO_COLOR}\n"
    # declare -a apis=(
    #     "cloudresourcemanager.googleapis.com"
    # )
    # for api in "${apis[@]}"; do
    #     printf "    Enabling: \033[1;34m$api\033[0m ...\n"
    #     gcloud services enable "$api" --project "$PROJECT_ID"
    # done
    # printf "    ✅ APIs enabled. Press Enter to Continue"
    # read -r -p ""

    # --> not needed: The cloud resource manager API is one of the few APIs that is enabled by default when you create a project. 
    # To create a folder as a child of the Org, you must have one of these roles assigned to you at the Organization level:
    #     - Folder Creator (roles/resourcemanager.folderCreator)
    #     - Folder Admin (roles/resourcemanager.folderAdmin)







    printf '\n'
    printf "▶️  Step: \033[1;32m'Folder Setup'\033[0m\n"
    save_var FOLDER_NAME "${FOLDER_NAME_SUFFIX}"
    printf "    Creating folder '${BLUE_BOLD}$FOLDER_NAME${NO_COLOR}' under '${BLUE_BOLD}$FOLDER_PARENT${NO_COLOR}'...\n"
    # Extract Parent ID and Type
    if [[ "$FOLDER_PARENT" == organization/* ]]; then
        PARENT_TYPE="organization"
        PARENT_ID="${FOLDER_PARENT#organization/}"
    elif [[ "$FOLDER_PARENT" == folder/* ]]; then
        PARENT_TYPE="folder"
        PARENT_ID="${FOLDER_PARENT#folder/}"
    else
        printf "    ❌ ERROR: Invalid FOLDER_PARENT format. Must start with 'organization/' or 'folder/'.\n"
        exit 1
    fi



    declare -a ORG_IAM_ROLES=(
        "roles/resourcemanager.projectCreator" # To create projects
    )
    if [[ "$FOLDER_PARENT" == organization/* ]]; then
        PARENT_ID="${FOLDER_PARENT#organization/}"
        printf "    Assigning permissions to user ${BLUE_NORMAL} $USER_ACCOUNT\033[0m on Organization ${YELLOW_BOLD} $PARENT_ID\033[0m...\n"
        ./scripts/iam-policy-add-org.sh "$PARENT_ID" "user:$USER_ACCOUNT" "${ORG_IAM_ROLES[@]}"
        
    elif [[ "$FOLDER_PARENT" == folder/* ]]; then
        PARENT_ID="${FOLDER_PARENT#folder/}"
        printf "    Assigning permissions to user ${BLUE_NORMAL} $USER_ACCOUNT\033[0m on Folder ${YELLOW_BOLD} $PARENT_ID\033[0m...\n"
        # Using folder helper script
        ./scripts/iam-policy-add-folder.sh "$PARENT_ID" "user:$USER_ACCOUNT" "${ORG_IAM_ROLES[@]}"
    else
        printf "    ⚠️  Unknown parent type for IAM assignment. Skipping automatic role assignment.\n"
    fi



    ## 2.2 Create
    gcloud resource-manager folders create --display-name="$FOLDER_NAME" --"$PARENT_TYPE"="$PARENT_ID"




    ## 2.3 Define Variable
    # Retrieve the new Folder ID
    FOLDER_ID=$(gcloud resource-manager folders list --"$PARENT_TYPE"="$PARENT_ID" --filter="displayName=${FOLDER_NAME}" --format="value(ID)" 2>/dev/null)
    printf "    ⏳ Waiting for folder to be available...\n"
    while [[ -z "$FOLDER_ID" ]]; do
        sleep 2
        FOLDER_ID=$(gcloud resource-manager folders list --"$PARENT_TYPE"="$PARENT_ID" --filter="displayName=${FOLDER_NAME}" --format="value(ID)" 2>/dev/null)
    done
    save_var FOLDER_ID "$FOLDER_ID"
    printf "    ✅ Folder Created. ID: \033[1;31m$FOLDER_ID\033[0m\n"
    printf "    ✅ Folder setup complete. Press Enter to Continue"
    if [[ "$AUTO_APPROVE" != "true" ]]; then
        read -r -p ""
    fi
#



































############################################################################################################
############################################################################################################
## 4. Project Setup (Create)

    # Check if ARGOLIS_BILLING_ID is set
    if [[ -n "$ARGOLIS_BILLING_ID" ]]; then
        save_var BILLING_ACCOUNT_ID "$ARGOLIS_BILLING_ID"
    else
        # Fallback to existing variable if set
        printf "    ❌ ERROR: \$ARGOLIS_BILLING_ID undefined. Make sure to add \`export ARGOLIS_BILLING_ID='<YOUR_BILLING_ID>'\` to your ~/.zshrc and source it.\n"
        exit 1
    fi

    # ## Check if BILLING_ACCOUNT_ID is set
    # if [[ -z "$BILLING_ACCOUNT_ID" ]]; then
    #     printf "    ❌ ERROR: \$ARGOLIS_BILLING_ID undefined. Make sure to add \`export ARGOLIS_BILLING_ID='<YOUR_BILLING_ID>'\` to your ~/.zshrc and source it.\n"
    #     exit 1
    # fi



    printf '\n'
    printf "▶️  Step: \033[1;32m'Project Setup'\033[0m\n"

    save_var PROJECT_ID "${PROJECT_NAME_PREFIX}-${RANDOM_SUFFIX}"
    save_var PROJECT_NAME "$PROJECT_ID"


    ## NOTE:there is no flag in the gcloud projects create command itself to skip the creation of the default network.
    ## The default network is generated by a background process triggered the moment a project is created
    ##
    # gcloud resource-manager org-policies enable-enforce \
    #     compute.skipDefaultNetworkCreation \
    #     --folder="$FOLDER_ID"



    printf "    Creating project '\033[1;32m$PROJECT_ID\033[0m' in folder '$FOLDER_ID'...\n"
    gcloud projects create "$PROJECT_ID" --folder="$FOLDER_ID" --name="$PROJECT_NAME" --quiet

    printf "    ✅ Project Created: \033[1;31m$PROJECT_ID\033[0m\n"

    # Set project as active
    gcloud config set project "$PROJECT_ID"

    gcloud auth application-default set-quota-project "$PROJECT_ID"

    gcloud config set billing/quota_project "$PROJECT_ID"


    # Link Billing
    declare -a apis=(
        "cloudbilling.googleapis.com"
        "cloudresourcemanager.googleapis.com"
    )
    for api in "${apis[@]}"; do
        printf "    Enabling: \033[1;34m$api\033[0m on project $PROJECT_ID...\n"
        gcloud services enable "$api" --project "$PROJECT_ID" #--async
        echo "Waiting for $api serive to be ACTIVE..."
        # Loop until the service appears in the 'enabled' list
        while [[ -z $(gcloud services list --enabled --filter="config.name:$api" --format="value(config.name)" --project="$PROJECT_ID") ]]; do
            echo "Current Status: PENDING... (checking again in 2 seconds)"
            sleep 2
        done
        printf "\033[0;32mSUCCESS:\033[0m Service \033[1;34m$api\033[0m is now ACTIVE on project $PROJECT_ID.\n"
    done

    # declare -a ORG_IAM_ROLES=(
    #     "roles/billing.user" # To link billing accounts
    # )
    # # if [[ "$FOLDER_PARENT" == organization/* ]]; then
    # #     PARENT_ID="${FOLDER_PARENT#organization/}"
    # #     printf "    Assigning permissions to user ${BLUE_NORMAL} $USER_ACCOUNT\033[0m on Organization ${YELLOW_BOLD} $PARENT_ID\033[0m...\n"
    # #     ./scripts/iam-policy-add-org.sh "$PARENT_ID" "user:$USER_ACCOUNT" "${ORG_IAM_ROLES[@]}"
    # #     
    # # elif [[ "$FOLDER_PARENT" == folder/* ]]; then
    # #     PARENT_ID="${FOLDER_PARENT#folder/}"
    # #     printf "    Assigning permissions to user ${BLUE_NORMAL} $USER_ACCOUNT\033[0m on Folder ${YELLOW_BOLD} $PARENT_ID\033[0m...\n"
    # #     # Using folder helper script
    # #     ./scripts/iam-policy-add-folder.sh "$PARENT_ID" "user:$USER_ACCOUNT" "${ORG_IAM_ROLES[@]}"
    # # else
    # #     printf "    ⚠️  Unknown parent type for IAM assignment. Skipping automatic role assignment.\n"
    # # fi
    # 
    # printf "    Assigning permissions to user ${BLUE_NORMAL} $USER_ACCOUNT\033[0m on Organization ${YELLOW_BOLD} $ORGANIZATION_ID\033[0m...\n"
    # ./scripts/iam-policy-add-org.sh "$ORGANIZATION_ID" "user:$USER_ACCOUNT" "${ORG_IAM_ROLES[@]}"
    # --> permission denied if do so. But we are already a billing admin.

    printf "    💳 Linking billing account '\033[1;32m$BILLING_ACCOUNT_ID\033[0m'...\n"
    gcloud alpha billing projects link "$PROJECT_ID" --billing-account "$BILLING_ACCOUNT_ID" #> /dev/null

    printf "    ✅ Project setup complete. Press Enter to Continue"
    if [[ "$AUTO_APPROVE" != "true" ]]; then
        read -r -p ""
    fi


#








































############################################################################################################
############################################################################################################
## 5. Enable Services

    ## Service sare enabled in their specific section so as to understand where did the service enablement requirement came from (a service required for gke for example would be enabled in the gke section)
    # printf '\n'
    # printf "▶️  Step: \033[1;32m'Enable Services'\033[0m\n"

    # declare -a apis=(
    #     "compute.googleapis.com"
    #     "container.googleapis.com"
    #     "iam.googleapis.com"
    #     "monitoring.googleapis.com"
    #     "orgpolicy.googleapis.com"
    #     "cloudresourcemanager.googleapis.com"
    #     "serviceusage.googleapis.com"
    # )

    # for api in "${apis[@]}"; do
    #     printf "    Enabling: \033[1;34m$api\033[0m ...\n"
    #     gcloud services enable "$api" --project "$PROJECT_ID"
    # done

    # printf "    ✅ APIs enabled. Press Enter to Continue"
    # read -r -p ""

#





























############################################################################################################
############################################################################################################

## 6. User Org Level IAM Roles



    # # Project IAM Configuration

    printf '\n'
    printf "▶️  Step: \033[1;32m'Project IAM Configuration'\033[0m\n"

    # Define Project-level roles
    declare -a PROJECT_IAM_ROLES=(
        "roles/owner"
        "roles/iam.securityAdmin"
        "roles/iam.serviceAccountAdmin"
        "roles/iam.serviceAccountKeyAdmin"
        "roles/iam.serviceAccountTokenCreator"
        "roles/logging.admin"
        "roles/monitoring.admin"
        "roles/monitoring.dashboardEditor"
        "roles/serviceusage.serviceUsageAdmin"
        "roles/storage.admin"
    )

    # Use helper script to assign roles to the user
    printf "    Assigning project administration roles to user \033[1;32m$USER_ACCOUNT\033[0m...\n"

    # Fix Argolis Policies
    ./scripts/iam-policy-add-project.sh "$PROJECT_ID" "user:$USER_ACCOUNT" "${PROJECT_IAM_ROLES[@]}"


    printf "    Adjusting Org Policies (Argolis Defaults)...\n"
    declare -a apis=(
        "orgpolicy.googleapis.com"
    )
    for api in "${apis[@]}"; do
        printf "    Enabling: \033[1;34m$api\033[0m on project $PROJECT_ID...\n"
        gcloud services enable "$api" --project "$PROJECT_ID" #--async
        echo "Waiting for $api serive to be ACTIVE..."
        # Loop until the service appears in the 'enabled' list
        while [[ -z $(gcloud services list --enabled --filter="config.name:$api" --format="value(config.name)" --project="$PROJECT_ID") ]]; do
            echo "Current Status: PENDING... (checking again in 2 seconds)"
            sleep 2
        done
        printf "\033[0;32mSUCCESS:\033[0m Service \033[1;34m$api\033[0m is now ACTIVE on project $PROJECT_ID.\n"
    done

    ./scripts/argolis-fix-policy-defaults.sh "$PROJECT_ID"

    printf "    ✅ IAM Configuration complete. Press Enter to Continue"
    if [[ "$AUTO_APPROVE" != "true" ]]; then
        read -r -p ""
    fi

#






























############################################################################################################
############################################################################################################
## 7. VPC Setup


    ## Network (VPC) Settings:

    printf '\n'
    printf "▶️  Step: \033[1;32m'VPC Setup'\033[0m\n"

    # Assign Network roles BEFORE creating network (though mostly needed for viewing/managing later)
    # or AFTER. Typically fine to do here.
    declare -a VPC_IAM_ROLES=(
        "roles/compute.viewer"
    )
    printf "    Assigning VPC/Compute permissions to user \033[1;32m$USER_ACCOUNT\033[0m...\n"
    ./scripts/iam-policy-add-project.sh "$PROJECT_ID" "user:$USER_ACCOUNT" "${VPC_IAM_ROLES[@]}"



    

    declare -a apis=(
        "compute.googleapis.com"
    )
    for api in "${apis[@]}"; do
        printf "    Enabling: \033[1;34m$api\033[0m on project $PROJECT_ID...\n"
        gcloud services enable "$api" --project "$PROJECT_ID" #--async
        echo "Waiting for $api serive to be ACTIVE..."
        # Loop until the service appears in the 'enabled' list
        while [[ -z $(gcloud services list --enabled --filter="config.name:$api" --format="value(config.name)" --project="$PROJECT_ID") ]]; do
            echo "Current Status: PENDING... (checking again in 2 seconds)"
            sleep 2
        done
        printf "\033[0;32mSUCCESS:\033[0m Service \033[1;34m$api\033[0m is now ACTIVE on project $PROJECT_ID.\n"
    done

    if [ "${NUM_VPCS:-0}" -ge 1 ]; then
        save_var VPC_1_NAME "vpc-prod1"
        VPC_NAME=${VPC_1_NAME}
        printf "    Creating VPC Network: \033[1;32m$VPC_NAME\033[0m ...\n"
        gcloud compute networks create "$VPC_NAME" \
            --project="$PROJECT_ID" \
            --subnet-mode=custom \
            --bgp-routing-mode=global \
            --quiet
        printf "    ✅ VPC ${VPC_NAME} Created.\n"
    fi

    if [ "${NUM_VPCS:-0}" -ge 2 ]; then
        save_var VPC_2_NAME "vpc-dev1"
        VPC_NAME=${VPC_2_NAME}
        printf "    Creating VPC Network: \033[1;32m$VPC_NAME\033[0m ...\n"
        gcloud compute networks create "$VPC_NAME" \
            --project="$PROJECT_ID" \
            --subnet-mode=custom \
            --bgp-routing-mode=global \
            --quiet
        printf "    ✅ VPC ${VPC_NAME} Created.\n"
    fi

    if [ "${NUM_VPCS:-0}" -ge 3 ]; then
        save_var VPC_3_NAME "vpc-prod2"
        VPC_NAME=${VPC_3_NAME}
        printf "    Creating VPC Network: \033[1;32m$VPC_NAME\033[0m ...\n"
        gcloud compute networks create "$VPC_NAME" \
            --project="$PROJECT_ID" \
            --subnet-mode=custom \
            --bgp-routing-mode=global \
            --quiet
        printf "    ✅ VPC ${VPC_NAME} Created.\n"
    fi


    
    # Wait for VPCs to be ready to avoid race conditions with subnet creation
    printf "    ⏳ Verifying VPC network readiness...\n"
    
    EXPECTED_VPCS=()
    [ "${NUM_VPCS:-0}" -ge 1 ] && EXPECTED_VPCS+=("$VPC_1_NAME")
    [ "${NUM_VPCS:-0}" -ge 2 ] && EXPECTED_VPCS+=("$VPC_2_NAME")
    [ "${NUM_VPCS:-0}" -ge 3 ] && EXPECTED_VPCS+=("$VPC_3_NAME")

    for vpc in "${EXPECTED_VPCS[@]}"; do
        printf "       Checking $vpc..."
        count=0
        while true; do
            STATUS=$(gcloud compute networks describe "$vpc" --project="$PROJECT_ID" --format="value(status)" 2>/dev/null)
            if [[ "$STATUS" == "READY" ]]; then
                printf " \033[1;32mREADY\033[0m\n"
                break
            fi
            
            if [ $count -ge 30 ]; then # Wait up to 60 seconds
                printf " \033[1;31mTIMEOUT\033[0m (proceeding anyway, but creation might fail)\n"
                break
            fi
            
            printf "."
            sleep 2
            ((count++))
        done
    done
    
    printf "    ✅ VPC(s) setup complete. Press Enter to Continue"
    if [[ "$AUTO_APPROVE" != "true" ]]; then
        read -r -p ""
    fi

#




























############################################################################################################
############################################################################################################
## 8. VPC Subnet Setup

# Define ranges and names for 3 subnets in case wanted to deploy clusters to dedicated subnets or to use for GCE instances.
# WE also add another subnet for gce instances but also subnets where the alias ranges are not defined in case wanted to see what gke creates.

save_var VPC1_SUBNET_NAME_USC1 "vpc1-subnet-us-central1-s1"
save_var VPC1_SUBNET_REGION_USC1 "us-central1"
save_var VPC1_SUBNET_RANGE_USC1 "10.128.0.0/18" # to 10.128.15.254 = 4094 hosts
save_var VPC1_POD_RANGE_USC1 "192.168.0.0/18"  #  64 /24s
save_var VPC1_POD_RANGE_NAME_USC1 "pods-us-central1"
save_var VPC1_SVC_RANGE_USC1 "172.16.0.0/18"   #  16382 IPs  # Managed Service Range: 34.118.224.0/20
save_var VPC1_SVC_RANGE_NAME_USC1 "svc-us-central1"
save_var VPC1_SUBNET_NAME_USC1b "vpc1-subnet-us-central1-s2"
save_var VPC1_SUBNET_REGION_USC1b "us-central1"
save_var VPC1_SUBNET_RANGE_USC1b "10.129.0.0/18" # for gce instances (purpose: ssh to and test access to endpoints from)

save_var VPC1_SUBNET_NAME_USW1 "vpc1-subnet-us-west1-s1"
save_var VPC1_SUBNET_REGION_USW1 "us-west1"
save_var VPC1_SUBNET_RANGE_USW1 "10.128.64.0/18" # to 10.128.79.254 = 4094 hosts
save_var VPC1_POD_RANGE_USW1 "192.168.64.0/18"
save_var VPC1_POD_RANGE_NAME_USW1 "pods-us-west1"
save_var VPC1_SVC_RANGE_USW1 "172.16.64.0/18"   #  16382 IPs  # Managed Service Range: 34.118.224.0/20
save_var VPC1_SVC_RANGE_NAME_USW1 "svc-us-west1"
save_var VPC1_SUBNET_NAME_USW1b "vpc1-subnet-us-west1-s2"
save_var VPC1_SUBNET_REGION_USW1b "us-west1"
save_var VPC1_SUBNET_RANGE_USW1b "10.129.64.0/18" # for gce instances (purpose: ssh to and test access to endpoints from)

save_var VPC1_SUBNET_NAME_USE1 "vpc1-subnet-us-east1-s1"
save_var VPC1_SUBNET_REGION_USE1 "us-east1"
save_var VPC1_SUBNET_RANGE_USE1 "10.128.128.0/18" # to 10.128.79.254 = 4094 hosts
save_var VPC1_POD_RANGE_USE1 "192.168.128.0/18"
save_var VPC1_POD_RANGE_NAME_USE1 "pods-us-east1"
save_var VPC1_SVC_RANGE_USE1 "172.16.128.0/18"   #  16382 IPs  # Managed Service Range: 34.118.224.0/20
save_var VPC1_SVC_RANGE_NAME_USE1 "svc-us-east1"
save_var VPC1_SUBNET_NAME_USE1b "vpc1-subnet-us-east1-s2"
save_var VPC1_SUBNET_REGION_USE1b "us-east1"
save_var VPC1_SUBNET_RANGE_USE1b "10.129.128.0/18" # for gce instances (purpose: ssh to and test access to endpoints from)






if [ "${NUM_REGIONS:-0}" -ge 1 ]; then
    printf '\n'
    printf "▶️  Step: \033[1;32m'${VPC_1_NAME} Subnet Setup'\033[0m\n"

    VPC_NAME=${VPC_1_NAME}
    SUBNET_NAME=${VPC1_SUBNET_NAME_USC1}
    SUBNET_REGION=${VPC1_SUBNET_REGION_USC1}
    SUBNET_RANGE=${VPC1_SUBNET_RANGE_USC1}
    POD_RANGE=${VPC1_POD_RANGE_USC1}
    POD_RANGE_NAME=${VPC1_POD_RANGE_NAME_USC1}
    SVC_RANGE=${VPC1_SVC_RANGE_USC1}
    SVC_RANGE_NAME=${VPC1_SVC_RANGE_NAME_USC1}

    printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
    gcloud compute networks subnets create "$SUBNET_NAME" \
        --project="$PROJECT_ID" \
        --network="$VPC_NAME" \
        --region="$SUBNET_REGION" \
        --range="$SUBNET_RANGE" \
        --secondary-range="$POD_RANGE_NAME=$POD_RANGE,$SVC_RANGE_NAME=$SVC_RANGE" \
        --quiet
    printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"

    SUBNET_NAME=${VPC1_SUBNET_NAME_USC1b}
    SUBNET_REGION=${VPC1_SUBNET_REGION_USC1b}
    SUBNET_RANGE=${VPC1_SUBNET_RANGE_USC1b}
    printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
    gcloud compute networks subnets create "$SUBNET_NAME" \
        --project="$PROJECT_ID" \
        --network="$VPC_NAME" \
        --region="$SUBNET_REGION" \
        --range="$SUBNET_RANGE" \
        --quiet
    printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"
fi


if [ "${NUM_REGIONS:-0}" -ge 2 ]; then
    SUBNET_NAME=${VPC1_SUBNET_NAME_USW1}
    SUBNET_REGION=${VPC1_SUBNET_REGION_USW1}
    SUBNET_RANGE=${VPC1_SUBNET_RANGE_USW1}
    POD_RANGE=${VPC1_POD_RANGE_USW1}
    POD_RANGE_NAME=${VPC1_POD_RANGE_NAME_USW1}
    SVC_RANGE=${VPC1_SVC_RANGE_USW1}
    SVC_RANGE_NAME=${VPC1_SVC_RANGE_NAME_USW1}

    printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
    gcloud compute networks subnets create "$SUBNET_NAME" \
        --project="$PROJECT_ID" \
        --network="$VPC_NAME" \
        --region="$SUBNET_REGION" \
        --range="$SUBNET_RANGE" \
        --secondary-range="$POD_RANGE_NAME=$POD_RANGE,$SVC_RANGE_NAME=$SVC_RANGE" \
        --quiet
    printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"

    SUBNET_NAME=${VPC1_SUBNET_NAME_USW1b}
    SUBNET_REGION=${VPC1_SUBNET_REGION_USW1b}
    SUBNET_RANGE=${VPC1_SUBNET_RANGE_USW1b}
    printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
    gcloud compute networks subnets create "$SUBNET_NAME" \
        --project="$PROJECT_ID" \
        --network="$VPC_NAME" \
        --region="$SUBNET_REGION" \
        --range="$SUBNET_RANGE" \
        --quiet
    printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"
fi


if [ "${NUM_REGIONS:-0}" -ge 3 ]; then
    SUBNET_NAME=${VPC1_SUBNET_NAME_USE1}
    SUBNET_REGION=${VPC1_SUBNET_REGION_USE1}
    SUBNET_RANGE=${VPC1_SUBNET_RANGE_USE1}
    POD_RANGE=${VPC1_POD_RANGE_USE1}
    POD_RANGE_NAME=${VPC1_POD_RANGE_NAME_USE1}
    SVC_RANGE=${VPC1_SVC_RANGE_USE1}
    SVC_RANGE_NAME=${VPC1_SVC_RANGE_NAME_USE1}

    printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
    gcloud compute networks subnets create "$SUBNET_NAME" \
        --project="$PROJECT_ID" \
        --network="$VPC_NAME" \
        --region="$SUBNET_REGION" \
        --range="$SUBNET_RANGE" \
        --secondary-range="$POD_RANGE_NAME=$POD_RANGE,$SVC_RANGE_NAME=$SVC_RANGE" \
        --quiet
    printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"

    SUBNET_NAME=${VPC1_SUBNET_NAME_USE1b}
    SUBNET_REGION=${VPC1_SUBNET_REGION_USE1b}
    SUBNET_RANGE=${VPC1_SUBNET_RANGE_USE1b}
    printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
    gcloud compute networks subnets create "$SUBNET_NAME" \
        --project="$PROJECT_ID" \
        --network="$VPC_NAME" \
        --region="$SUBNET_REGION" \
        --range="$SUBNET_RANGE" \
        --quiet
    printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"

    printf "    ✅ vpc1 subnets setup complete. Press Enter to Continue"
    if [[ "$AUTO_APPROVE" != "true" ]]; then
        read -r -p ""
    fi
fi




























# Define ranges and names for 3 subnets in case wanted to deploy clusters to dedicated subnets or to use for GCE instances.
# VPC2 is meant to be a dev vpc mimicing vpc1 prod. So same cidrs defined.








if [ "${NUM_VPCS:-0}" -ge 2 ]; then
    save_var VPC2_SUBNET_NAME_USC1 "vpc2-subnet-us-central1-s1"
    save_var VPC2_SUBNET_REGION_USC1 "us-central1"
    save_var VPC2_SUBNET_RANGE_USC1 "10.128.0.0/18" # to 10.128.15.254 = 4094 hosts
    save_var VPC2_POD_RANGE_USC1 "192.168.0.0/18"  #  64 /24s
    save_var VPC2_POD_RANGE_NAME_USC1 "pods-us-central1"
    save_var VPC2_SVC_RANGE_USC1 "172.16.0.0/18"   #  16382 IPs  # Managed Service Range: 34.118.224.0/20
    save_var VPC2_SVC_RANGE_NAME_USC1 "svc-us-central1"
    save_var VPC2_SUBNET_NAME_USC1b "vpc2-subnet-us-central1-s2"
    save_var VPC2_SUBNET_REGION_USC1b "us-central1"
    save_var VPC2_SUBNET_RANGE_USC1b "10.129.0.0/18"

    save_var VPC2_SUBNET_NAME_USW1 "vpc2-subnet-us-west1-s1"
    save_var VPC2_SUBNET_REGION_USW1 "us-west1"
    save_var VPC2_SUBNET_RANGE_USW1 "10.128.64.0/18" # to 10.128.79.254 = 4094 hosts
    save_var VPC2_POD_RANGE_USW1 "192.168.64.0/18"
    save_var VPC2_POD_RANGE_NAME_USW1 "pods-us-west1"
    save_var VPC2_SVC_RANGE_USW1 "172.16.64.0/18"   #  16382 IPs  # Managed Service Range: 34.118.224.0/20
    save_var VPC2_SVC_RANGE_NAME_USW1 "svc-us-west1"
    save_var VPC2_SUBNET_NAME_USW1b "vpc2-subnet-us-west1-s2"
    save_var VPC2_SUBNET_REGION_USW1b "us-west1"
    save_var VPC2_SUBNET_RANGE_USW1b "10.129.64.0/18"

    save_var VPC2_SUBNET_NAME_USE1 "vpc2-subnet-us-east1-s1"
    save_var VPC2_SUBNET_REGION_USE1 "us-east1"
    save_var VPC2_SUBNET_RANGE_USE1 "10.128.128.0/18" # to 10.128.79.254 = 4094 hosts
    save_var VPC2_POD_RANGE_USE1 "192.168.128.0/18"
    save_var VPC2_POD_RANGE_NAME_USE1 "pods-us-east1"
    save_var VPC2_SVC_RANGE_USE1 "172.16.128.0/18"   #  16382 IPs  # Managed Service Range: 34.118.224.0/20
    save_var VPC2_SVC_RANGE_NAME_USE1 "svc-us-east1"
    save_var VPC2_SUBNET_NAME_USE1b "vpc2-subnet-us-east1-s2"
    save_var VPC2_SUBNET_REGION_USE1b "us-east1"
    save_var VPC2_SUBNET_RANGE_USE1b "10.129.128.0/18"

    printf '\n'
    printf "▶️  Step: \033[1;32m'${VPC_2_NAME} Subnet Setup'\033[0m\n"
    VPC_NAME=${VPC_2_NAME}
    if [ "${NUM_REGIONS:-0}" -ge 1 ]; then
        SUBNET_NAME=${VPC2_SUBNET_NAME_USC1}
        SUBNET_REGION=${VPC2_SUBNET_REGION_USC1}
        SUBNET_RANGE=${VPC2_SUBNET_RANGE_USC1}
        POD_RANGE=${VPC2_POD_RANGE_USC1}
        POD_RANGE_NAME=${VPC2_POD_RANGE_NAME_USC1}
        SVC_RANGE=${VPC2_SVC_RANGE_USC1}
        SVC_RANGE_NAME=${VPC2_SVC_RANGE_NAME_USC1}
        printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
        gcloud compute networks subnets create "$SUBNET_NAME" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --region="$SUBNET_REGION" \
            --range="$SUBNET_RANGE" \
            --secondary-range="$POD_RANGE_NAME=$POD_RANGE,$SVC_RANGE_NAME=$SVC_RANGE" \
            --quiet
        printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"

        SUBNET_NAME=${VPC2_SUBNET_NAME_USC1b}
        SUBNET_REGION=${VPC2_SUBNET_REGION_USC1b}
        SUBNET_RANGE=${VPC2_SUBNET_RANGE_USC1b}
        printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
        gcloud compute networks subnets create "$SUBNET_NAME" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --region="$SUBNET_REGION" \
            --range="$SUBNET_RANGE" \
            --quiet
        printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"
    fi


    if [ "${NUM_REGIONS:-0}" -ge 2 ]; then
        SUBNET_NAME=${VPC2_SUBNET_NAME_USW1}
        SUBNET_REGION=${VPC2_SUBNET_REGION_USW1}
        SUBNET_RANGE=${VPC2_SUBNET_RANGE_USW1}
        POD_RANGE=${VPC2_POD_RANGE_USW1}
        POD_RANGE_NAME=${VPC2_POD_RANGE_NAME_USW1}
        SVC_RANGE=${VPC2_SVC_RANGE_USW1}
        SVC_RANGE_NAME=${VPC2_SVC_RANGE_NAME_USW1}

        printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
        gcloud compute networks subnets create "$SUBNET_NAME" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --region="$SUBNET_REGION" \
            --range="$SUBNET_RANGE" \
            --secondary-range="$POD_RANGE_NAME=$POD_RANGE,$SVC_RANGE_NAME=$SVC_RANGE" \
            --quiet
        printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"


        SUBNET_NAME=${VPC2_SUBNET_NAME_USW1b}
        SUBNET_REGION=${VPC2_SUBNET_REGION_USW1b}
        SUBNET_RANGE=${VPC2_SUBNET_RANGE_USW1b}

        printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
        gcloud compute networks subnets create "$SUBNET_NAME" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --region="$SUBNET_REGION" \
            --range="$SUBNET_RANGE" \
            --quiet
        printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"
    fi


    if [ "${NUM_REGIONS:-0}" -ge 3 ]; then
        SUBNET_NAME=${VPC2_SUBNET_NAME_USE1}
        SUBNET_REGION=${VPC2_SUBNET_REGION_USE1}
        SUBNET_RANGE=${VPC2_SUBNET_RANGE_USE1}
        POD_RANGE=${VPC2_POD_RANGE_USE1}
        POD_RANGE_NAME=${VPC2_POD_RANGE_NAME_USE1}
        SVC_RANGE=${VPC2_SVC_RANGE_USE1}
        SVC_RANGE_NAME=${VPC2_SVC_RANGE_NAME_USE1}

        printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
        gcloud compute networks subnets create "$SUBNET_NAME" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --region="$SUBNET_REGION" \
            --range="$SUBNET_RANGE" \
            --secondary-range="$POD_RANGE_NAME=$POD_RANGE,$SVC_RANGE_NAME=$SVC_RANGE" \
            --quiet
        printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"



        SUBNET_NAME=${VPC2_SUBNET_NAME_USE1b}
        SUBNET_REGION=${VPC2_SUBNET_REGION_USE1b}
        SUBNET_RANGE=${VPC2_SUBNET_RANGE_USE1b}

        printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
        gcloud compute networks subnets create "$SUBNET_NAME" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --region="$SUBNET_REGION" \
            --range="$SUBNET_RANGE" \
            --quiet
        printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"
    fi
    printf "    ✅ vpc2 Subnets setup complete. Press Enter to Continue"
    if [[ "$AUTO_APPROVE" != "true" ]]; then
        read -r -p ""
    fi
fi























# Define ranges and names for 3 subnets in case wanted to deploy clusters to dedicated subnets or to use for GCE instances.
#VPC3 is created with subnet cidrs that would allow VPC3 to interconnect (VPC peering) with the first vpc. i.e. no overlapping cidrs.





if [ "${NUM_VPCS:-0}" -ge 3 ]; then

    save_var VPC3_SUBNET_NAME_USC1 "vpc3-subnet-us-central1-s1"
    save_var VPC3_SUBNET_REGION_USC1 "us-central1"
    save_var VPC3_SUBNET_RANGE_USC1 "10.130.0.0/18" # to 10.128.15.254 = 4094 hosts
    save_var VPC3_POD_RANGE_USC1 "192.169.0.0/18"  #  64 /24s
    save_var VPC3_POD_RANGE_NAME_USC1 "pods-us-central1"
    save_var VPC3_SVC_RANGE_USC1 "172.16.0.0/18"   #  16382 IPs  # Managed Service Range: 34.118.224.0/20
    save_var VPC3_SVC_RANGE_NAME_USC1 "svc-us-central1"
    save_var VPC3_SUBNET_NAME_USC1b "vpc3-subnet-us-central1-s2"
    save_var VPC3_SUBNET_REGION_USC1b "us-central1"
    save_var VPC3_SUBNET_RANGE_USC1b "10.131.0.0/18"


    save_var VPC3_SUBNET_NAME_USW1 "vpc3-subnet-us-west1-s1"
    save_var VPC3_SUBNET_REGION_USW1 "us-west1"
    save_var VPC3_SUBNET_RANGE_USW1 "10.130.64.0/18" # to 10.128.79.254 = 4094 hosts
    save_var VPC3_POD_RANGE_USW1 "192.169.64.0/18"
    save_var VPC3_POD_RANGE_NAME_USW1 "pods-us-west1"
    save_var VPC3_SVC_RANGE_USW1 "172.16.64.0/18"   #  16382 IPs  # Managed Service Range: 34.118.224.0/20
    save_var VPC3_SVC_RANGE_NAME_USW1 "svc-us-west1"
    save_var VPC3_SUBNET_NAME_USW1b "vpc3-subnet-us-west1-s2"
    save_var VPC3_SUBNET_REGION_USW1b "us-west1"
    save_var VPC3_SUBNET_RANGE_USW1b "10.131.64.0/18"

    save_var VPC3_SUBNET_NAME_USE1 "vpc3-subnet-us-east1-s1"
    save_var VPC3_SUBNET_REGION_USE1 "us-east1"
    save_var VPC3_SUBNET_RANGE_USE1 "10.130.128.0/18" # to 10.128.79.254 = 4094 hosts
    save_var VPC3_POD_RANGE_USE1 "192.169.128.0/18"
    save_var VPC3_POD_RANGE_NAME_USE1 "pods-us-east1"
    save_var VPC3_SVC_RANGE_USE1 "172.16.128.0/18"   #  16382 IPs  # Managed Service Range: 34.118.224.0/20
    save_var VPC3_SVC_RANGE_NAME_USE1 "svc-us-east1"
    save_var VPC3_SUBNET_NAME_USE1b "vpc3-subnet-us-east1-s2"
    save_var VPC3_SUBNET_REGION_USE1b "us-east1"
    save_var VPC3_SUBNET_RANGE_USE1b "10.131.128.0/18"



    printf '\n'
    printf "▶️  Step: \033[1;32m'${VPC_3_NAME} Subnet Setup'\033[0m\n"

    VPC_NAME=${VPC_3_NAME}
    if [ "${NUM_REGIONS:-0}" -ge 1 ]; then
        SUBNET_NAME=${VPC3_SUBNET_NAME_USC1}
        SUBNET_REGION=${VPC3_SUBNET_REGION_USC1}
        SUBNET_RANGE=${VPC3_SUBNET_RANGE_USC1}
        POD_RANGE=${VPC3_POD_RANGE_USC1}
        POD_RANGE_NAME=${VPC3_POD_RANGE_NAME_USC1}
        SVC_RANGE=${VPC3_SVC_RANGE_USC1}
        SVC_RANGE_NAME=${VPC3_SVC_RANGE_NAME_USC1}

        printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
        gcloud compute networks subnets create "$SUBNET_NAME" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --region="$SUBNET_REGION" \
            --range="$SUBNET_RANGE" \
            --secondary-range="$POD_RANGE_NAME=$POD_RANGE,$SVC_RANGE_NAME=$SVC_RANGE" \
            --quiet
        printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"



        SUBNET_NAME=${VPC3_SUBNET_NAME_USC1b}
        SUBNET_REGION=${VPC3_SUBNET_REGION_USC1b}
        SUBNET_RANGE=${VPC3_SUBNET_RANGE_USC1b}

        printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
        gcloud compute networks subnets create "$SUBNET_NAME" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --region="$SUBNET_REGION" \
            --range="$SUBNET_RANGE" \
            --quiet
        printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"
    fi


    if [ "${NUM_REGIONS:-0}" -ge 2 ]; then
        SUBNET_NAME=${VPC3_SUBNET_NAME_USW1}
        SUBNET_REGION=${VPC3_SUBNET_REGION_USW1}
        SUBNET_RANGE=${VPC3_SUBNET_RANGE_USW1}
        POD_RANGE=${VPC3_POD_RANGE_USW1}
        POD_RANGE_NAME=${VPC3_POD_RANGE_NAME_USW1}
        SVC_RANGE=${VPC3_SVC_RANGE_USW1}
        SVC_RANGE_NAME=${VPC3_SVC_RANGE_NAME_USW1}

        printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
        gcloud compute networks subnets create "$SUBNET_NAME" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --region="$SUBNET_REGION" \
            --range="$SUBNET_RANGE" \
            --secondary-range="$POD_RANGE_NAME=$POD_RANGE,$SVC_RANGE_NAME=$SVC_RANGE" \
            --quiet
        printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"


        SUBNET_NAME=${VPC3_SUBNET_NAME_USW1b}
        SUBNET_REGION=${VPC3_SUBNET_REGION_USW1b}
        SUBNET_RANGE=${VPC3_SUBNET_RANGE_USW1b}

        printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
        gcloud compute networks subnets create "$SUBNET_NAME" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --region="$SUBNET_REGION" \
            --range="$SUBNET_RANGE" \
            --quiet
        printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"
    fi


    if [ "${NUM_REGIONS:-0}" -ge 3 ]; then
        SUBNET_NAME=${VPC3_SUBNET_NAME_USE1}
        SUBNET_REGION=${VPC3_SUBNET_REGION_USE1}
        SUBNET_RANGE=${VPC3_SUBNET_RANGE_USE1}
        POD_RANGE=${VPC3_POD_RANGE_USE1}
        POD_RANGE_NAME=${VPC3_POD_RANGE_NAME_USE1}
        SVC_RANGE=${VPC3_SVC_RANGE_USE1}
        SVC_RANGE_NAME=${VPC3_SVC_RANGE_NAME_USE1}

        printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
        gcloud compute networks subnets create "$SUBNET_NAME" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --region="$SUBNET_REGION" \
            --range="$SUBNET_RANGE" \
            --secondary-range="$POD_RANGE_NAME=$POD_RANGE,$SVC_RANGE_NAME=$SVC_RANGE" \
            --quiet
        printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"


        SUBNET_NAME=${VPC3_SUBNET_NAME_USE1b}
        SUBNET_REGION=${VPC3_SUBNET_REGION_USE1b}
        SUBNET_RANGE=${VPC3_SUBNET_RANGE_USE1b}

        printf "    Creating Subnet: \033[1;32m$SUBNET_NAME\033[0m in \033[1;34m$SUBNET_REGION\033[0m ...\n"
        gcloud compute networks subnets create "$SUBNET_NAME" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --region="$SUBNET_REGION" \
            --range="$SUBNET_RANGE" \
            --quiet
        printf "    ✅ Subnet ${SUBNET_NAME} Created.\n"
    fi
    printf "    ✅ vpc3 Subnets setup complete. Press Enter to Continue"
    if [[ "$AUTO_APPROVE" != "true" ]]; then
        read -r -p ""
    fi

fi


















############################################################################################################
############################################################################################################
## 9. VPC Firewall Rules

#suggested by cloudshell after creating vpc
#$ gcloud compute firewall-rules create <FIREWALL_NAME> --network vpc-dev1 --allow tcp,udp,icmp --source-ranges <IP_RANGE>
#$ gcloud compute firewall-rules create <FIREWALL_NAME> --network vpc-dev1 --allow tcp:22,tcp:3389,icmp

    if [ "${NUM_VPCS:-0}" -ge 1 ]; then
        printf '\n'
        printf "▶️  Step: \033[1;32m'VPC Firewall Rules VPC1'\033[0m\n"

        VPC_NAME=${VPC_1_NAME}
        SUBNET_RANGE_USC1=${VPC1_SUBNET_RANGE_USC1}
        SUBNET_RANGE_USW1=${VPC1_SUBNET_RANGE_USW1}
        SUBNET_RANGE_USE1=${VPC1_SUBNET_RANGE_USE1}
        SUBNET_RANGE_USC1b=${VPC1_SUBNET_RANGE_USC1b}
        SUBNET_RANGE_USW1b=${VPC1_SUBNET_RANGE_USW1b}
        SUBNET_RANGE_USE1b=${VPC1_SUBNET_RANGE_USE1b}


        # Allow internal traffic within the VPC - Region 1 (USC1)
        gcloud compute firewall-rules create "${VPC_NAME}-allow-internal" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --allow=tcp,udp,icmp \
            --source-ranges="$SUBNET_RANGE_USC1","$SUBNET_RANGE_USC1b" \
            --description="Allow internal traffic from subnet" \
            --quiet

        if [ "${NUM_REGIONS:-0}" -ge 2 ]; then
            # Add Region 2 (USW1)
            gcloud compute firewall-rules update "${VPC_NAME}-allow-internal" \
                --project="$PROJECT_ID" \
                --source-ranges="$SUBNET_RANGE_USC1","$SUBNET_RANGE_USC1b","$SUBNET_RANGE_USW1","$SUBNET_RANGE_USW1b" \
                --quiet
        fi

        if [ "${NUM_REGIONS:-0}" -ge 3 ]; then
            # Add Region 3 (USE1)
            gcloud compute firewall-rules update "${VPC_NAME}-allow-internal" \
                --project="$PROJECT_ID" \
                --source-ranges="$SUBNET_RANGE_USC1","$SUBNET_RANGE_USC1b","$SUBNET_RANGE_USW1","$SUBNET_RANGE_USW1b","$SUBNET_RANGE_USE1","$SUBNET_RANGE_USE1b" \
                --quiet
        fi



        # Allow SSH from IAP (Identity-Aware Proxy)
        gcloud compute firewall-rules create "${VPC_NAME}-allow-ssh-iap" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --allow=tcp:22 \
            --source-ranges="35.235.240.0/20" \
            --description="Allow SSH from IAP" \
            --quiet

        # Allow ICMP from anywhere (Optional, good for testing)
        gcloud compute firewall-rules create "${VPC_NAME}-allow-icmp" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --allow=icmp \
            --source-ranges="0.0.0.0/0" \
            --description="Allow ICMP from anywhere" \
            --quiet

        printf "    ✅ Firewall Rules Created for VPC1.\n"
    fi


















    if [ "${NUM_VPCS:-0}" -ge 2 ]; then
        printf '\n'
        printf "▶️  Step: \033[1;32m'VPC Firewall Rules VPC2'\033[0m\n"

        VPC_NAME=${VPC_2_NAME}
        SUBNET_RANGE_USC1=${VPC2_SUBNET_RANGE_USC1}
        SUBNET_RANGE_USW1=${VPC2_SUBNET_RANGE_USW1}
        SUBNET_RANGE_USE1=${VPC2_SUBNET_RANGE_USE1}
        SUBNET_RANGE_USC1b=${VPC2_SUBNET_RANGE_USC1b}
        SUBNET_RANGE_USW1b=${VPC2_SUBNET_RANGE_USW1b}
        SUBNET_RANGE_USE1b=${VPC2_SUBNET_RANGE_USE1b}


        # Allow internal traffic within the VPC - Region 1 (USC1)
        gcloud compute firewall-rules create "${VPC_NAME}-allow-internal" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --allow=tcp,udp,icmp \
            --source-ranges="$SUBNET_RANGE_USC1","$SUBNET_RANGE_USC1b" \
            --description="Allow internal traffic from subnet" \
            --quiet

        if [ "${NUM_REGIONS:-0}" -ge 2 ]; then
            # Add Region 2 (USW1)
            gcloud compute firewall-rules update "${VPC_NAME}-allow-internal" \
                --project="$PROJECT_ID" \
                --source-ranges="$SUBNET_RANGE_USC1","$SUBNET_RANGE_USC1b","$SUBNET_RANGE_USW1","$SUBNET_RANGE_USW1b" \
                --quiet
        fi

        if [ "${NUM_REGIONS:-0}" -ge 3 ]; then
            # Add Region 3 (USE1)
            gcloud compute firewall-rules update "${VPC_NAME}-allow-internal" \
                --project="$PROJECT_ID" \
                --source-ranges="$SUBNET_RANGE_USC1","$SUBNET_RANGE_USC1b","$SUBNET_RANGE_USW1","$SUBNET_RANGE_USW1b","$SUBNET_RANGE_USE1","$SUBNET_RANGE_USE1b" \
                --quiet
        fi


        # Allow SSH from IAP (Identity-Aware Proxy)
        gcloud compute firewall-rules create "${VPC_NAME}-allow-ssh-iap" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --allow=tcp:22 \
            --source-ranges="35.235.240.0/20" \
            --description="Allow SSH from IAP" \
            --quiet

        # Allow ICMP from anywhere (Optional, good for testing)
        gcloud compute firewall-rules create "${VPC_NAME}-allow-icmp" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --allow=icmp \
            --source-ranges="0.0.0.0/0" \
            --description="Allow ICMP from anywhere" \
            --quiet

        printf "    ✅ Firewall Rules Created for VPC2.\n"


    fi






















    if [ "${NUM_VPCS:-0}" -ge 3 ]; then
        printf '\n'
        printf "▶️  Step: \033[1;32m'VPC Firewall Rules VPC3'\033[0m\n"

        VPC_NAME=${VPC_3_NAME}
        SUBNET_RANGE_USC1=${VPC3_SUBNET_RANGE_USC1}
        SUBNET_RANGE_USW1=${VPC3_SUBNET_RANGE_USW1}
        SUBNET_RANGE_USE1=${VPC3_SUBNET_RANGE_USE1}
        SUBNET_RANGE_USC1b=${VPC3_SUBNET_RANGE_USC1b}
        SUBNET_RANGE_USW1b=${VPC3_SUBNET_RANGE_USW1b}
        SUBNET_RANGE_USE1b=${VPC3_SUBNET_RANGE_USE1b}

        # Allow internal traffic within the VPC - Region 1 (USC1)
        gcloud compute firewall-rules create "${VPC_NAME}-allow-internal" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --allow=tcp,udp,icmp \
            --source-ranges="$SUBNET_RANGE_USC1","$SUBNET_RANGE_USC1b" \
            --description="Allow internal traffic from subnet" \
            --quiet

        if [ "$NUM_REGIONS" -ge 2 ]; then
            # Add Region 2 (USW1)
            gcloud compute firewall-rules update "${VPC_NAME}-allow-internal" \
                --project="$PROJECT_ID" \
                --source-ranges="$SUBNET_RANGE_USC1","$SUBNET_RANGE_USC1b","$SUBNET_RANGE_USW1","$SUBNET_RANGE_USW1b" \
                --quiet
        fi

        if [ "$NUM_REGIONS" -ge 3 ]; then
            # Add Region 3 (USE1)
            gcloud compute firewall-rules update "${VPC_NAME}-allow-internal" \
                --project="$PROJECT_ID" \
                --source-ranges="$SUBNET_RANGE_USC1","$SUBNET_RANGE_USC1b","$SUBNET_RANGE_USW1","$SUBNET_RANGE_USW1b","$SUBNET_RANGE_USE1","$SUBNET_RANGE_USE1b" \
                --quiet
        fi

        # Allow SSH from IAP (Identity-Aware Proxy)
        gcloud compute firewall-rules create "${VPC_NAME}-allow-ssh-iap" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --allow=tcp:22 \
            --source-ranges="35.235.240.0/20" \
            --description="Allow SSH from IAP" \
            --quiet

        # Allow ICMP from anywhere (Optional, good for testing)
        gcloud compute firewall-rules create "${VPC_NAME}-allow-icmp" \
            --project="$PROJECT_ID" \
            --network="$VPC_NAME" \
            --allow=icmp \
            --source-ranges="0.0.0.0/0" \
            --description="Allow ICMP from anywhere" \
            --quiet

        printf "    ✅ Firewall Rules Created for VPC3.\n"


    fi











    ##NOTE a config.json file is created for our gcloud client: "Created enterprise-certificate-proxy configuration file [/etc/certificate_config.json]"
    ## {
    ##   "cert_configs": {
    ##     "macos_keychain": {
    ##       "issuer": "enterprise_v1_corp_client-signer-0-2018-07-03T10:55:10-07:00 K:1, 2:BXmhnePmGN4:0:18",
    ##       "keychain_type": "all"
    ##     }
    ##   },
    ##   "libs": {
    ##     "ecp": "/Users/meillier/google-cloud-sdk/bin/ecp",
    ##     "ecp_client": "/Users/meillier/google-cloud-sdk/platform/enterprise_cert/libecp.dylib",
    ##     "tls_offload": "/Users/meillier/google-cloud-sdk/platform/enterprise_cert/libtls_offload.dylib"
    ##   }
    ## NOTE: gcloud integrated itself with your Corporate Device Identity. This is a high-security feature often enforced by "BeyondCorp" or "Context-Aware Access" policies. It ensures that only "managed devices" can manage your Google Cloud resources.
    ## look at the "macos_keychain" section. 
    ## This indicates that your machine (likely a corporate-managed Mac) already has a certificate issued by Google's internal Certificate Authority (the "enterprise_v1_corp_client-signer...").
    ## gcloud scanned your macOS Keychain, found a certificate that matches Google's "Enterprise Certificate Proxy" (ECP) standards, and wrote this JSON file so it knows which libraries (.dylib) to use to talk to your keychain
    ## It provides Device Identity. Even if someone stole your gcloud login credentials (username/password), they wouldn't be able to run commands from a different computer because that computer wouldn't have the hardware-backed certificate listed in your macos_keychain





    printf "    ✅ Firewall setup complete. Press Enter to Continue"
    if [[ "$AUTO_APPROVE" != "true" ]]; then
        read -r -p ""
    fi

    printf '\n'
    printf "🎉 \033[1;32m GCP Infra Setup Complete. \033[0m\n"
    printf "   Project ID: ${RED_BOLD} ${PROJECT_ID} ${NO_COLOR}\n"
    printf "   VPC:        ${RED_BOLD} ${VPC_NAME} ${NO_COLOR}\n"
    printf "   VPC URL:    ${RED_BOLD} https://console.cloud.google.com/networking/networks/list?project=${PROJECT_ID} ${NO_COLOR}\n"
    echo "https://console.cloud.google.com/networking/networks/list?project=${PROJECT_ID}" > .url-vpc.txt


#
























# ############################################################################################################
# ############################################################################################################
# ## 10. Fleet Setup


## 4. Project Setup (Create)

    # # Check if ARGOLIS_BILLING_ID is set
    # if [[ -n "$ARGOLIS_BILLING_ID" ]]; then
    #     save_var BILLING_ACCOUNT_ID "$ARGOLIS_BILLING_ID"
    # else
    #     # Fallback to existing variable if set
    #     printf "    ❌ ERROR: \$ARGOLIS_BILLING_ID undefined. Make sure to add \`export ARGOLIS_BILLING_ID='<YOUR_BILLING_ID>'\` to your ~/.zshrc and source it.\n"
    #     exit 1
    # fi

    # ## Check if BILLING_ACCOUNT_ID is set
    # if [[ -z "$BILLING_ACCOUNT_ID" ]]; then
    #     printf "    ❌ ERROR: \$BILLING_ACCOUNT_ID undefined. Make sure to add \`export ARGOLIS_BILLING_ID='<YOUR_BILLING_ID>'\` to your ~/.zshrc and source it.\n"
    #     exit 1
    # fi



    printf '\n'
    printf "▶️  Step: \033[1;32m'Fleet Project Setup'\033[0m\n"

    save_var PROJECT_ID_FLEET "${PROJECT_NAME_PREFIX}-${RANDOM_SUFFIX}-fleet"
    save_var PROJECT_NAME_FLEET "${PROJECT_ID_FLEET}"


    ## NOTE:there is no flag in the gcloud projects create command itself to skip the creation of the default network.
    ## The default network is generated by a background process triggered the moment a project is created
    ##
    # gcloud resource-manager org-policies enable-enforce \
    #     compute.skipDefaultNetworkCreation \
    #     --folder="$FOLDER_ID"



    printf "    Creating project '\033[1;32m$PROJECT_ID_FLEET\033[0m' in folder '$FOLDER_ID'...\n"
    gcloud projects create "${PROJECT_ID_FLEET}" --folder="$FOLDER_ID" --name="${PROJECT_NAME_FLEET}" --quiet

    printf "    ✅ Project Created: \033[1;31m${PROJECT_ID_FLEET}\033[0m\n"

    ## Set project as active
    #gcloud config set project "$PROJECT_ID"
    #
    #gcloud auth application-default set-quota-project "$PROJECT_ID"
    #
    #gcloud config set billing/quota_project "$PROJECT_ID"


    # Link Billing
    declare -a apis=(
        "cloudbilling.googleapis.com"
        "cloudresourcemanager.googleapis.com"
        "iam.googleapis.com"
    )
    for api in "${apis[@]}"; do
        printf "    Enabling: \033[1;34m$api\033[0m on project $PROJECT_ID_FLEET...\n"
        gcloud services enable "$api" --project "${PROJECT_ID_FLEET}" #--async
        echo "Waiting for $api service to be ACTIVE..."
        # Loop until the service appears in the 'enabled' list
        while [[ -z $(gcloud services list --enabled --filter="config.name:$api" --format="value(config.name)" --project="$PROJECT_ID_FLEET") ]]; do
            echo "Current Status: PENDING... (checking again in 2 seconds)"
            sleep 2
        done
        printf "\033[0;32mSUCCESS:\033[0m Service \033[1;34m$api\033[0m is now ACTIVE on project $PROJECT_ID_FLEET.\n"
    done

    printf "    💳 Linking billing account '\033[1;32m$BILLING_ACCOUNT_ID\033[0m'...\n"
    gcloud alpha billing projects link "$PROJECT_ID_FLEET" --billing-account "$BILLING_ACCOUNT_ID" #> /dev/null

    printf "    ✅ Fleet Project setup complete. Press Enter to Continue"
    if [[ "$AUTO_APPROVE" != "true" ]]; then
        read -r -p ""
    fi


#


























printf '\n'
printf "▶️  Step: \033[1;32m'Fleet Setup on ${PROJECT_ID_FLEET}'\033[0m\n"

    # 1. Enable Fleet APIs
        # You need to enable the following APIs in your fleet host project (https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/before-you-begin#enable_apis)
        #         container.googleapis.com
        #         gkeconnect.googleapis.com
        #         gkehub.googleapis.com, also known as the Fleet API. This is the Google Cloud service that handles cluster registration and fleet membership.
        #         cloudresourcemanager.googleapis.com
        # If you want to enable fleet Workload Identity for your registration, you must also enable the following:
        #         iam.googleapis.com
        
    declare -a fleet_apis=(
        "container.googleapis.com"
        "gkeconnect.googleapis.com"
        "gkehub.googleapis.com"
        "cloudresourcemanager.googleapis.com"
    )
        for api in "${fleet_apis[@]}"; do
            printf "    Enabling: \033[1;34m$api\033[0m on project $PROJECT_ID_FLEET...\n"
            gcloud services enable "$api" --project "$PROJECT_ID_FLEET" #--async
            echo "Waiting for $api service to be ACTIVE..."
            while [[ -z $(gcloud services list --enabled --filter="config.name:$api" --format="value(config.name)" --project="$PROJECT_ID_FLEET") ]]; do
                echo "Current Status: PENDING... (checking again in 2 seconds)"
                sleep 2
            done
        done
        printf "    ✅ Fleet APIs enabled.\n"





    # 2. Fleet IAM Roles
    # Cluster Registration iam roles: https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/before-you-begin#grant_cluster_registration_permissions
    # Cluster registration requires both permission to register the cluster to a fleet, and admin permissions on the cluster itself
    #  If you have roles/owner in your fleet host project, you have this automatically and have all the access permissions you need to complete all registration tasks.


    declare -a FLEET_IAM_ROLES=(
        "roles/gkehub.admin"
    )
    printf "    Assigning Fleet permissions to user \033[1;32m$USER_ACCOUNT\033[0m...\n"
    ./scripts/iam-policy-add-project.sh "$PROJECT_ID_FLEET" "user:$USER_ACCOUNT" "${FLEET_IAM_ROLES[@]}"

    printf "    ✅ Fleet setup complete. Press Enter to Continue"
    if [[ "$AUTO_APPROVE" != "true" ]]; then
        read -r -p ""
    fi




    #roles/container.admin: "your user account is likely to have it if you created the cluster"
        #https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/before-you-begin#clusters_on





    # Empty Fleet: https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/fleet-creation#optional_create_an_empty_fleet
        # By default, a new fleet is created in your fleet host project the first time you register a cluster in that project. 
        # If you want to create a new named fleet before you register any clusters (for example, to set up scopes for team access), run the following command:
    FLEET_NAME="My-Fleet-project-05713-fleet"
    gcloud container fleet create --display-name=$FLEET_NAME --project=$PROJECT_ID_FLEET  
        # WARNING: ECP proxy failed to start on port 64218: Proxy process terminated unexpectedly with code 1 while waiting for it to start.
        # Waiting for operation [projects/project-05713-fleet/locations/global/operations/operation-1771970849061-64b991d02baa7-f9fe318d-560772cb] to complete...done.                      
        # Created Anthos fleet [https://gkehub.googleapis.com/v1alpha/projects/project-05713-fleet/locations/global/fleets/default].
        # NAME     LOCATION  STATUS
        # default  global    READY

    #gcloud config set project $PROJECT_ID_FLEET
    #gcloud auth application-default set-quota-project $PROJECT_ID_FLEET
    #gcloud config set billing/quota_project "$PROJECT_ID_FLEET"
    #
    # gcloud container fleet list
        # Listing fleets from organization 1061229561493:
        # DISPLAY_NAME                  PROJECT        UID
        # My-Fleet-project-05713-fleet  1076653660692  d301b12f-696e-4cc6-bd8a-56e3cf1586ae



# 
# ## GKE FLeet: 
# #
# #  Why:
# #     Fleets are managed by the Fleet service, also known as the Hub service
# #     Without fleets, if you want to make a production-wide change to clusters, you need to make the change on the individual clusters, in multiple projects. 
# #     Even observing multiple clusters can require switching context between projects.
# #     However, fleets can be more than just simple groups of clusters. You can build on fleets by enabling fleet-based features that let you abstract away cluster boundaries
# #         Fleet Based Features (https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/fleet-concepts/fleet-features#onboarding_low_risk_features)
# #         - Fleet based rollout sequencing (the primary purpose of a "lightweight membership" for GKE clusters on Google Cloud within a Fleet is to enable the use of fleet-based rollout sequencing for cluster upgrades, while intentionally excluding other fleet-level configurations and features.)
# #         - Fleet Observability
# #         - Security Posture
# #         - Advanced vulnerability insights
# #         - Compliance posture
# #         - Config Sync (Config Sync lets you deploy and monitor declarative configuration packages for your system stored in a central source of truth, like a Git repository, leveraging core Kubernetes concepts such as namespaces, labels, and annotations. With Config Sync, configuration are defined across the fleet, but applied and enforced locally in each of the member resources)
# #         - Binary Authorization (does not strictly requires fleet tho)
# #         - Policy Controller (Policy Controller lets you apply and enforce declarative policies for your Kubernetes clusters. These policies act as guardrails and can help with best practices, security, and compliance management of your clusters and fleet.)
# #         - Fleet Team Management
# #         - Fleet logging
# #         - Fleet resource utilization metrics
# #         - Cross cluster inter-node transparent encryption (single cluster does not require fleet node-2-node encryption)
# #         - Connect gateway
# #         - GKE Identity Service (https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/manage-features#fleet-level_features)
# #         Advanced multi-cluster features:
# #         - Fleet Workload Identity Federation
# #         - Cloud Service Mesh
# #         - Multi-cluster Gateway
# #         - Multi cluster ingress
# # 
# #     Fleet Features at: 
# #         - https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/fleet-concepts/fleet-features#feature_requirements
# # 
# #     Fleet Defaults: https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/fleet-concepts/fleet-features#fleet-level_defaults
# #             GKE provides the ability to set fleet-level defaults for certain features, including Cloud Service Mesh, Config Sync, and Policy Controller. 
# #             This helps you set up clusters to use these features without having to configure each cluster individually. 
# #             For example, an administrator can enable Policy Controller for their fleet and set default policies at the fleet level. This installs the required agent in new fleet member clusters and applies default policies to them.
# #             Enabling Fleet- level Defaults: https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/manage-features#configure_fleet-level_defaults
# 
# # Creating a Fleet
# #       - Option 1: By registering a cluster: When you register a cluster of any type in a project that doesn't already have a fleet, a new fleet is created and the project becomes a fleet host project. 
# #       - Option 2: You can create an empty fleet before you register clusters to it.
# ##
# # Create an empty fleet: 
# #       By default, a new fleet is created in your fleet host project the first time you register a cluster in that project. 
# #       If you want to create a new named fleet before you register any clusters (for example, to set up scopes for team access), run the following command:
#gcloud container fleet create --display-name="fleet-project" --project=${PROJECT_ID_FLEET}
# #
# # Services: You need to enable the following APIs in your fleet host project (https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/before-you-begin#enable_apis)
# #        container.googleapis.com
# #        gkeconnect.googleapis.com
# #        gkehub.googleapis.com, also known as the Fleet API. This is the Google Cloud service that handles cluster registration and fleet membership.
# #        cloudresourcemanager.googleapis.com
# #
# # IAM Roles:
# #       roles/gkehub.admin
# #
# #
# # Selective Fleet Features Enablement on host project: (https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/manage-features#enable_features)
# #       As an alternative to fleet default configuration, you can choose to configure fleet features separately on individual clusters
# #       Each fleet-level feature has its own enable command. For example, to enable GKE Identity Service for your fleet, you run the following command in your fleet host project
# #       Note that this step is not required for all features.
# #
# 
#
#
#
#
# # REgister clusters to Fleet (at creation or update. Fleet can exist, or will be created upon first creating cluster joined to a fleet)
# #
# # Option A: Registration without Connect Gateway setup:
# # About Registering Cluster on Google cloud: (https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/register/gke)
# #       - GKE Std:              gcloud container clusters create ${CLUSTER_NAME} --enable-fleet --workload-pool=${PROJECT_ID}.svc.id.goog
# #       - GKE Std Lightweight:  gcloud container clusters create CLUSTER_NAME --enable-fleet --membership-type=LIGHTWEIGHT
# #       - GKE AP:               gcloud container clusters create-auto CLUSTER_NAME --enable-fleet
# #       - GKE AP Lightweight:   gcloud container clusters create-auto CLUSTER_NAME --enable-fleet --membership-type=LIGHTWEIGHT
# #
# # Register an existing Cluster:
# #       gcloud container clusters update CLUSTER_NAME --enable-fleet
# #       gcloud container clusters update CLUSTER_NAME --enable-fleet --membership-type=LIGHTWEIGHT
# #
# ## Register a cluster to fleet as lightweight fleet member but with connect agent:
#     # https://docs.cloud.google.com/sdk/gcloud/reference/container/fleet/memberships/register?content_ref=register%20a%20gke%20cluster%20use%20gke%20cluster%20or%20gke%20uri%20flag%20no%20kubeconfig%20flag%20is%20required%20connect%20agent%20will%20not%20be%20installed%20by%20default%20for%20gke%20clusters
# # About lightweight membership: https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/fleet-creation#lightweight_memberships
# #       GKE clusters on Google Cloud support lightweight memberships, which let you register the cluster as a fleet member without enabling all of the fleet-level configurations and features.
# #       Clusters that use a lightweight membership can use fleet-based rollout sequencing for cluster upgrades. 
# #       Today (Jan 2026) the primary purpose of a "lightweight membership" for GKE clusters on Google Cloud within a Fleet is to enable the use of fleet-based rollout sequencing for cluster upgrades, while intentionally excluding other fleet-level configurations and features.
# #       Lightweight memberships prevent clusters from using the following fleet-level configurations:
# #         - Fleet-level features
# #         - Fleet-level default logs
# #         - Fleet-level default metrics
# #         - Fleet Workload Identity Federation
# #
# # Convert Lightweight Fleet-registered cluster to regular membership
# #       gcloud container clusters update CLUSTER_NAME --unset-membership-type
# # 
# # Option B: If have connect gateway setup -
# #       Registration to fleet via 'gcloud container fleet'
#         # gcloud container fleet memberships register my-gke-cluster \
#         #     --gke-cluster=us-central1-a/my-gke-cluster \
#         #     --project=my-gcp-project \
#         #     --install-connect-agent \
#         #     --enable-workload-identity
# #  you use the --install-connect-agent flag with the gcloud container fleet memberships register command
# #     # Example registering a GKE cluster and forcing Connect Agent installation
# #     gcloud container fleet memberships register my-gke-cluster \
# #         --gke-cluster=us-central1-a/my-gke-cluster \
# #         --project=my-gcp-project \
# #         --install-connect-agent \
# #         --enable-workload-identity
# 
# 
# 
# 
# 
# 
# 
# 
# 
# ### About Fleet Workload IDentity Federation (https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/about-fleet-workload-identity-federation)
# #
# # Intro: https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/fleet-concepts/fleet-features#consider_workload_identity
# #   This extends the capabilities provided in Workload Identity Federation for GKE, which lets the workloads in your cluster authenticate to Google without requiring you to download, manually rotate, and generally manage Google Cloud service account keys. 
# #   Instead, workloads authenticate using short-lived tokens generated by the clusters, with each cluster added as an identity provider to a special workload identity pool. 
# #   Workloads running in a specific namespace can share the same Identity and Access Management identity across clusters
# #   While regular Workload Identity Federation for GKE uses a project-wide identity pool, fleet-wide Workload Identity Federation uses a workload identity pool for the entire fleet, even if the clusters are in different projects, with implicit sameness for identities across the fleet as well as namespace and service sameness.
# #   This makes it simpler to set up authentication for your applications across projects, but can have access control considerations over and above those for regular Workload Identity Federation for GKE if you choose to use it in multi-project fleets, particularly if the fleet host project has a mixture of fleet and non-fleet clusters.
# #
# #   Also see Identity Sameness diagram here: https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/fleet-concepts#identity_sameness_when_accessing_external_resources
# #
# # If you want to enable fleet Workload Identity for your registration, you must also enable the following:
# #        iam.googleapis.com
# #
# # Registering a GKE cluster with fleet Workload Identity Federation without having Workload Identity Federation for GKE enabled on the cluster can lead to inconsistencies on how identity is asserted by workloads in the cluster, 
# # and is not a supported configuration. Autopilot clusters have Workload Identity Federation for GKE enabled by default.
# #
# # Workload Identity Federation for GKE and Fleet Workload Identity Federation are not the same, and using GKE Workload Identity (often referred to as identity federation for GKE) does not necessarily require Fleet Workload Identity Federation.
# #
# # While both features are built on the same underlying Workload Identity Pools mechanism, they serve different purposes and operate differently:
# # - Workload Identity Pools: 
# #     This is the foundational Google Cloud IAM resource used to manage external identities ( go/wl-id-pools). 
# #     Both GKE-specific and Fleet-wide federation use these pools to map Kubernetes identities to Google Cloud identities ( go/gke-workload-identity).
# # - GKE Workload Identity (Standard): This is the "traditional" way to authenticate GKE workloads on Google Cloud. 
# #     It uses a gke-metadata-server running on each node to automatically intercept requests to the metadata server and provide tokens ( go/gke-workload-identity-support).
# #     It is a cluster-local feature and does not require the cluster to be part of a Fleet ( go/gke-workload-identity-support).
# # - Fleet Workload Identity Federation: This extends the concept to a group of clusters (a Fleet). 
# #     It allows you to manage identities across multiple clusters, including those outside of Google Cloud (like on-premises or other clouds) ( https://g3doc.corp.google.com/company/gfw/support/cloud/products/anthos/gke-hub/workload-identity.md?content_ref=fleet+workload+identity+works+similarly+to+gke+workload+identity+on+the+backend+but+workloads+include+code+to+exchange+tokens+instead+of+relying+on+the+gke+metadata+server).
# #     Unlike the standard GKE version, it often relies on "in-process" token exchange using client libraries instead of a metadata server ( go/cloud-architecture/...).
# #
# # Key Distinctions:
# # - Scope: GKE Workload Identity is cluster-specific, while Fleet Workload Identity Federation is designed for multi-cluster management and "identity sameness" across a fleet ( source).
# # - Compatibility: If you use lightweight membership for your fleet, Fleet Workload Identity Federation is explicitly disabled, yet the clusters can still use their own cluster-local Workload Identity setup.
# # - Implementation: Standard GKE WI provides a "drop-in" experience via the metadata server, whereas Fleet WIF typically requires updated client libraries to handle the token exchange directly ( go/gke-workload-identi...).
# #
# # In summary, Workload Identity Pools are the "storage" for these identities, and Fleet Workload Identity Federation is an optional, higher-level management layer that you only need if you want unified identity management across a fleet of clusters ( source).
# 
# 
# 
# 
# ### Setup Connect Gateway
# #
# # Connect Gateway to interact with Cluster: https://docs.cloud.google.com/kubernetes-engine/enterprise/multicluster-management/gateway
# #
# # The Connect gateway builds on the power of fleets to let GKE users connect to and run commands against fleet member clusters in a simple, consistent, and secured way, whether the clusters are on Google Cloud, other public clouds, or on-premises, and makes it easier to automate DevOps processes across all your clusters.
# #       - By default the Connect gateway uses your Google ID to authenticate to clusters, 
# #       - with support for third party identity providers using workforce identity federation, and 
# #       - with group-based authentication support via GKE Identity Service
# # Also from https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs#authenticating_to_clusters:
# #       the Connect gateway builds on fleets to provide a consistent way to connect to and run commands against your registered clusters from the command line, and makes it simpler to automate DevOps tasks across multiple clusters, including clusters outside Google Cloud. 
# #       Users don't need direct IP connectivity to a cluster to connect to it using this option. Find out more in the Connect gateway guide.
# #
# ## Enable APIs: https://docs.cloud.google.com/kubernetes-engine/enterprise/multicluster-management/gateway/setup#enable_apis
# #       - connectgateway.googleapis.com \
# #
# #  IAM Roles for using kubectl via the connect Gateway (https://docs.cloud.google.com/kubernetes-engine/enterprise/multicluster-management/gateway/setup#grant_iam_roles_to_users)
# #       users and service accounts need the following IAM roles to use kubectl to interact with clusters through the Connect gateway, unless the user has roles/owner in the project:
# #      - roles/gkehub.gatewayAdmin  - lets a user access the Connect gateway API to use kubectl to manage the cluster
# #      - roles/gkehub.gatewayEditor - If a user needs read / write access to connected clusters
# #      - roles/gkehub.viewer        - This role lets a user retrieve cluster kubeconfigs
# #
# #  kubectl rbac roles for user: Authenticated users who want to access a cluster's resources in the Google Cloud console need to have the relevant Kubernetes permissions to do so.
# #      gcloud container fleet memberships generate-gateway-rbac  \
# #            --membership=MEMBERSHIP_NAME \
# #            --role=ROLE \. <-- clusterrole/cluster-admin, clusterrole/cloud-console-reader*, or role/mynamespace/namespace-reader *: role is not a default k8s role so needs to be created. (https://docs.cloud.google.com/kubernetes-engine/enterprise/multicluster-management/gateway/setup#optional_create_a_cloud-console-reader_role)
# #            --users=USERS \
# #            --project=PROJECT_ID \
# #            --kubeconfig=KUBECONFIG_PATH \
# #            --context=KUBECONFIG_CONTEXT \
# #            --apply
# #
# # Use Connect Gateway: (https://docs.cloud.google.com/kubernetes-engine/enterprise/multicluster-management/gateway/using)
# #       gcloud container fleet memberships get-credentials MEMBERSHIP_NAME. 
# #                   This command returns a special Connect gateway-specific kubeconfig that lets you connect to the cluster through the Connect gateway.
# #                   If you want to use a service account rather than your own Google Cloud account, use gcloud config to set auth/impersonate_service_account to the service account email address
# #
# #
# ### Note: Setup Connect Gateway with Google Groups: https://docs.cloud.google.com/kubernetes-engine/enterprise/multicluster-management/gateway/setup-groups
# #
# 
# 
# ### Connect Agent & GKE no GCP Clusters (for connection to fully private clusters - no GKEDNS, public, or private endpoints)
# #      The Connect Agent is not installed by default on GKE clusters running on Google Cloud when they are registered to a Fleet. 
# #      The primary design goal for the Connect Agent was to connect clusters external to Google Cloud (like on-premises, other clouds) into a Google Cloud Fleet (go/gkeconnect). 
# #      GKE clusters on GCP have other native ways to connect to the control plane.
# #
# #      For clusters external to GCP, when you register your Kubernetes clusters with Google Cloud using Connect, a long-lived, authenticated and encrypted connection is established between your clusters and the Google Cloud control plane (https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/connect-agent/what-uses-connect)
# #       When you register a cluster outside Google Cloud to your fleet, Google Cloud uses a Deployment called the Connect Agent to establish a connection between the cluster and your Google Cloud project, and to handle Kubernetes requests
# 
# #       Use Cases on GKE-on-GCP: Despite the default, there are valid reasons to install the Connect Agent on a GKE-on-GCP cluster. The main use case is to enable access via the Connect Gateway (go/connectgateway), especially for:
# #               Fully private clusters where you want to avoid bastion hosts.
# #               Standardizing cluster access methods across a mixed Fleet of GKE-on-GCP and external clusters.
# #               Utilizing Fleet features that rely on the Connect Agent
# #
# #      Connection Diagrams at: https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/connect-agent/security-features
# #
# #       1. Outbound Connection: The Connect Agent, running as a Deployment within your GKE cluster, initiates an outbound gRPC connection to the Connect Gateway service running on Google Cloud. This does not require any inbound ports to be opened on your cluster's control plane from the internet.
# #       2. Secure Tunnel: This outbound connection establishes a secure tunnel between the cluster and Google Cloud.
# #       3. User Authentication to GCP: You, as a user, authenticate to Google Cloud using your gcloud credentials, which have the necessary IAM permissions on the project and Fleet.
# #       4. Access via Connect Gateway API: When you run kubectl commands (after configuring kubeconfig to use the Connect Gateway), the requests are sent to the public Connect Gateway API endpoint (e.g., connectgateway.googleapis.com).
# #       5. IAM Authorization: Connect Gateway checks if your Google identity has the required IAM permissions to access the gateway and the target cluster membership within the Fleet (e.g., roles like roles/gkehub.gatewayAdmin).
# #       6. Request Forwarding: If IAM checks pass, Connect Gateway forwards your request through the established tunnel to the Connect Agent running in your cluster.
# #       7. Agent to API Server: The Connect Agent then proxies the request to the Kubernetes API server's private endpoint within the cluster.
# #       8. Kubernetes RBAC: The API server performs its standard Kubernetes Role-Based Access Control (RBAC) checks to ensure your identity (as asserted by the Connect Gateway/Agent, often using Kubernetes impersonation) is authorized to perform the requested action. 
# #
# # !!! Connect agent will not be installed by default for GKE clusters. To install it, specify --install-connect-agent
# #   ypm: Agent can be used for a user to access GKE cluster that has no DNS Endpoint and no public endpoint. Access via my local workstation outside the vpc
# #         gcloud container fleet memberships register my-gke-cluster \
# #             --gke-cluster=us-central1-a/my-gke-cluster \
# #             --project=my-gcp-project \
# #             --install-connect-agent \
# #             --enable-workload-identity
# 
# #
# #   IAM Roles: You need to provide specific IAM roles to launch the Connect Agent and interact with your cluster using the Google Cloud console or Google Cloud CLI. 
# #       - roles/gkehub.editor
# #       - roles/gkehub.viewer
# #       - roles/gkehub.connect <-- Only to establish connection between external clusters and Google (? but workaround for internal only clusters??)
# 
# 
# ## Connect Gateway for Google Group and 3rd party authentication via GKE IS
# # - Google Cloud identity: If you want to use Google Cloud as your identity provider, the Connect gateway builds on fleets to provide a consistent way to connect to and run commands against your registered clusters from the command line, and makes it simpler to automate DevOps tasks across multiple clusters, including clusters outside Google Cloud. 
# #     Users don't need direct IP connectivity to a cluster to connect to it using this option. Find out more in the Connect gateway guide.
# # 
# # - Third-party identity: Fleets also support using your existing third-party identity provider, such as Microsoft ADFS, letting you configure your fleet clusters so that users can log in with their existing third-party ID and password. 
# #         OIDC and LDAP providers are supported. 
# #         Find out more in Set up the connect gateway with third party identities and Introducing GKE Identity Service.
# # (https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs#authenticating_to_clusters)
















































































































############################################################################################################
############################################################################################################
## 11. GKE Setup

printf '\n'
printf "▶️  Step: \033[1;32m'GKE Cluster Setup'\033[0m Press Enter to Continue\n"
read -r -p ""


# 1. Enable K8s API
    declare -a gke_apis=(
        "container.googleapis.com"
    )
    for api in "${gke_apis[@]}"; do
        printf "    Enabling: \033[1;34m$api\033[0m on project $PROJECT_ID...\n"
        gcloud services enable "$api" --project "$PROJECT_ID" #--async
        echo "Waiting for $api service to be ACTIVE..."
        while [[ -z $(gcloud services list --enabled --filter="config.name:$api" --format="value(config.name)" --project="$PROJECT_ID") ]]; do
            echo "Current Status: PENDING... (checking again in 2 seconds)"
            sleep 2
        done
    done
    printf "    ✅ GKE APIs enabled.\n"
#


# 2. GKE IAM Roles
    declare -a GKE_IAM_ROLES=(
        "roles/container.admin"
    )
    printf "    Assigning GKE permissions to user \033[1;32m$USER_ACCOUNT\033[0m...\n"
    ./scripts/iam-policy-add-project.sh "$PROJECT_ID" "user:$USER_ACCOUNT" "${GKE_IAM_ROLES[@]}"
#


# 3. Dedicated Service Account for GKE Nodes
    printf "    Creating Dedicated Service Account for GKE Nodes...\n"

    save_var GKE_NODE_SA_NAME "gke-custom-sa"

    save_var GKE_NODE_SA_EMAIL "${GKE_NODE_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

    # Check if SA exists
    if ! gcloud iam service-accounts describe "$GKE_NODE_SA_EMAIL" --project "$PROJECT_ID" > /dev/null 2>&1; then
        gcloud iam service-accounts create "$GKE_NODE_SA_NAME" \
            --display-name="GKE Node Service Account" \
            --project "$PROJECT_ID" \
            --quiet
        printf "    ✅ Created Service Account: \033[1;32m$GKE_NODE_SA_EMAIL\033[0m\n"
    else
        printf "    ℹ️  Service Account \033[1;32m$GKE_NODE_SA_EMAIL\033[0m already exists.\n"
    fi

    # Wait for Service Account to be propagated
    printf "    ⏳ Waiting for Service Account propagation...\n"
    until gcloud iam service-accounts describe "$GKE_NODE_SA_EMAIL" --project "$PROJECT_ID" > /dev/null 2>&1; do
        echo -n "."
        sleep 2
    done
    printf "\n"
    # Additional buffer for IAM consistency across services
    sleep 10

    # Assign roles/container.defaultNodeServiceAccount
    printf "    Assigning roles/container.defaultNodeServiceAccount to gke custom SA...\n"
    ./scripts/iam-policy-add-project.sh "$PROJECT_ID" "serviceAccount:$GKE_NODE_SA_EMAIL" "roles/container.defaultNodeServiceAccount"
    
    # About artifactregistry.reader:
        # If your Artifact Registry is in the same project as your GKE cluster, nodes can often pull images by default via internal service agent permissions.
        # If you are pulling from a different project or have a highly restricted environment, you must explicitly add the roles/artifactregistry.reader role to your custom service account.
    printf "    Assigning roles/artifactregistry.reader to gke custom SA...\n"
    ./scripts/iam-policy-add-project.sh "$PROJECT_ID" "serviceAccount:$GKE_NODE_SA_EMAIL" "roles/artifactregistry.reader"




    ## Yes, you are exactly right. The roles/container.defaultNodeServiceAccount role is the modern, pre-packaged "least privilege" role designed specifically for GKE nodes.
    ## It was created to replace the over-privileged Compute Engine default service account (which often has the Editor role) and bundles together the exact permissions a node needs to function properly.
    ##The roles/container.defaultNodeServiceAccount role includes the following essential permissions:
            ##logging.logWriter: Allows the node to send system and workload logs to Cloud Logging.
            ##monitoring.metricWriter: Allows the node to send metrics (like CPU and memory usage) to Cloud Monitoring.
            ##monitoring.viewer: Allows the node to retrieve monitoring data.
            ##stackdriver.resourceMetadata.writer: Helps associate logs and metrics with the correct GKE cluster resources.




# 4. Create Cluster
printf "▶️  Step: \033[1;32m'GKE Cluster(s) Creation'\033[0m Verify Code for cluster intent and Press Enter to Continue\n"
if [[ "$AUTO_APPROVE" != "true" ]]; then
    read -r -p ""
fi

#printf "    Creating GKE Cluster(s): \033[1;32m$GKE_CLUSTER_NAME\033[0m ...\n"
#printf "    location: $GKE_CP_REGION_OR_ZONE | Zones: $GKE_ZONES | Nodes: $GKE_NUM_NODES | Type: $GKE_MACHINE_TYPE\n"


## Most Basic using defaults.
#gcloud container clusters create $GKE_CLUSTER_NAME \
#    --location $GKE_CP_REGION_OR_ZONE \
#    --service-account=$GKE_NODE_SA_EMAIL
#
## All Parameters
# gcloud container clusters create "$GKE_CLUSTER_NAME" \
#     --project "$PROJECT_ID" \
#
#     --location "$GKE_CP_REGION_OR_ZONE" \ 
        # (formerly --region) | or  --zone for zonal cluster but can use a zone as --location [https://docs.cloud.google.com/sdk/gcloud/reference/container/clusters/create#--location]
#     --node-locations "$GKE_NODES_ZONES" \
        #If not specified, all nodes will be in the cluster's primary zone (for zonal clusters) or spread across three randomly chosen zones within the cluster's region (for regional clusters)
        #Zonal Cluster: The control plane (master) is located in a single zone. By default, the nodes are also in that same zone.
        #Regional Cluster: The control plane is replicated across three zones in a region ( Creating a zonal clust...).
        #Multi-zonal Cluster: This is a specific type of zonal cluster. The control plane is still in one zone, but you use the --node-locations flag to spread your nodes across additional zones for better availability ( Creating a zonal clust...).
#
#     --release-channel "$GKE_RELEASE_CHANNEL" \ #rapid, regular*, stable, or None  (*: if no --cluster-version; --no-enable-autoupgrade; and --no-enable-autorepair )
#     --cluster-version $VERSION
        ##List available versions per channel:
        ##          gcloud container get-server-config \
        ##            --region us-central1 \
        ##            --format="yaml(channels)"
        ##
        ##          gcloud container get-server-config \
        ##            --region us-central1 \
        ##            --format="yaml(validMasterVersions)"
#
#     --num-nodes "$GKE_NUM_NODES" \
#     --machine-type "$GKE_MACHINE_TYPE" \
#     --network "$GKE_NET" \
#     --subnetwork "$GKE_SUBNET" \
#     --cluster-secondary-range-name "pods" \
#     --services-secondary-range-name "services" \
#     --enable-ip-alias \
#     --workload-pool "${PROJECT_ID}.svc.id.goog" \
#     --no-enable-master-authorized-networks \
#     --quiet
#    
# printf "    ✅ GKE Cluster Created.\n"
# printf "    ✅ Setup complete. Press Enter to Continue"
# read -r -p ""




# The premise of this lab is to deploy various cluster configurations to test what gets implemented under the hood. 
# Understanding the effect of a setting requires deploying one cluster with the setting and one without. For example 
# - a cluster with VPC native vs Routed cluster. 
# - a cluster with workload identity enabled vs not.
# - a cluster with DNS endpoint and ip-based endpoint vs a cluster with just ip-based endpoints.
# - an ip-based endpoint cluster with external endpoint enabled vs external endpoint disabled.
# - ...

# There are two approaches that could be used:
#  - 1. two separate projects but with the exact same VPC configurations. Same subnets cidrs, ...
#  - 2. Single project with two VPC  and overlapping IPs for subnets. However some constructs such as service accounts would be the same in the project. For example the custom GKE service account. IF we wanted to investigate the effect of a missing iam permission (e.g. permission to create vpc subnets in host project), we would need to use differe SAs.
#  - 3. A single project with a single VPC  and dedicated vpc subnets for each cluster.
# 
# Our GCP foundation was created to provide flexibility on how to perform those side by side comparisons. 





# GKE Cluster Settings:
 
 PARENT_FOLDER=$(basename $(dirname "$PWD"))
 # Sanitize and truncate parent folder name for label using bash expansion to avoid subshell/tr issues
 CLEAN_LABEL="${PARENT_FOLDER//[\/.-]/_}"
 save_var GKE_LABEL "${CLEAN_LABEL:0:62}" # label assigned to cluster so that we know which code deployed it.


    # VPCs:
    # - VPC_1_NAME
    # - VPC_2_NAME
    # - VPC_3_NAME
    # 
    # Subnets: where x = 1,2, or 3 and where REG = [USC, USW, USE]
    # - VPC<x>_SUBNET_NAME_<REG>1
    #     VPCx_SUBNET_REGION_USC1
    #     VPCx_SUBNET_RANGE_USC1
    #     VPCx_POD_RANGE_USC1
    #     VPCx_POD_RANGE_NAME_USC1
    #     VPCx_SVC_RANGE_USC1
    #     VPCx_SVC_RANGE_NAME_USC1
    # - VPCx_SUBNET_NAME_USC1b
    #     VPCx_SUBNET_REGION_USC1b
    #     VPCx_SUBNET_RANGE_USC1b
    # 
    # 
    #             VPCx_SUBNET_NAME_USC1
    #                 VPCx_SUBNET_REGION_USC1
    #                 VPCx_SUBNET_RANGE_USC1 "10.128.0.0/18" # to 10.128.15.254 = 4094 hosts
    #                 VPCx_POD_RANGE_USC1 "192.168.0.0/18"  #  64 /24s
    #                 VPCx_POD_RANGE_NAME_USC1 "pods-us-central1"
    #                 VPCx_SVC_RANGE_USC1 "172.16.0.0/18"   #  16382 IPs  # Managed Service Range: 34.118.224.0/20
    #                 VPCx_SVC_RANGE_NAME_USC1 "svc-us-central1"
    #             VPCx_SUBNET_NAME_USC1b "vpc1-subnet-b-us-central1"
    #                 VPCx_SUBNET_REGION_USC1b "us-central1"
    #                 VPCx_SUBNET_RANGE_USC1b "10.129.0.0/18"
    # 
    #             VPCx_SUBNET_NAME_USW1
    #                 VPCx_SUBNET_REGION_USW1
    #                 VPCx_SUBNET_RANGE_USW1 "10.128.64.0/18" # to 10.128.15.254 = 4094 hosts
    #                 VPCx_POD_RANGE_USW1 "192.168.64.0/18"  #  64 /24s
    #                 VPCx_POD_RANGE_NAME_USW1 "pods-us-west1"
    #                 VPCx_SVC_RANGE_USW1 "172.16.64.0/18"   #  16382 IPs  # Managed Service Range: 34.118.224.0/20
    #                 VPCx_SVC_RANGE_NAME_USW1 "svc-us-west1"
    #             VPCx_SUBNET_NAME_USW1b "vpc1-subnet-b-us-west1"
    #                 VPCx_SUBNET_REGION_USW1b "us-west"
    #                 VPCx_SUBNET_RANGE_USW1b "10.129.64.0/18"
    # 
    #             VPCx_SUBNET_NAME_USE1
    #                 VPCx_SUBNET_REGION_USE1
    #                 VPCx_SUBNET_RANGE_USE1 "10.128.128.0/18" # to 10.128.15.254 = 4094 hosts
    #                 VPCx_POD_RANGE_USE1 "192.168.128.0/18"  #  64 /24s
    #                 VPCx_POD_RANGE_NAME_USE1 "pods-us-east1"
    #                 VPCx_SVC_RANGE_USE1 "172.16.128.0/18"   #  16382 IPs  # Managed Service Range: 34.118.224.0/20
    #                 VPCx_SVC_RANGE_NAME_USE1 "svc-us-east1"
    #             VPCx_SUBNET_NAME_USE1b "vpc1-subnet-b-us-east1"
    #                 VPCx_SUBNET_REGION_USE1b "us-east1"
    #                 VPCx_SUBNET_RANGE_USE1b "10.129.128.0/18"


    ##     e.g.
    ##     save_var VPC1_SUBNET_NAME_USC1 "vpc1-subnet-us-central1"
    ##     save_var VPC1_SUBNET_REGION_USC1 "us-central1"
    ##     save_var VPC1_SUBNET_RANGE_USC1 "10.128.0.0/18" # to 10.128.15.254 = 4094 hosts
    ##     save_var VPC1_POD_RANGE_USC1 "192.168.0.0/18"  #  64 /24s
    ##     save_var VPC1_POD_RANGE_NAME_USC1 "pods-us-central1"
    ##     save_var VPC1_SVC_RANGE_USC1 "172.16.0.0/18"   #  16382 IPs  # Managed Service Range: 34.118.224.0/20
    ##     save_var VPC1_SVC_RANGE_NAME_USC1 "svc-us-central1"
    ##     save_var VPC1_SUBNET_NAME_USC1b "vpc1-subnet-b-us-central1"
    ##     save_var VPC1_SUBNET_REGION_USC1b "us-central1"
    ##     save_var VPC1_SUBNET_RANGE_USC1b "10.129.0.0/18" # for gce instances (purpose: ssh to and test access to endpoints from)
 









# Base Core - Good to use as baseline to see the default settings used. (e.g. VPC native, no dns endpoint, public,...). 
#    # + --subnetwork (cause don't want to rely on the 'default' subnet being there so point to our own)
# gcloud container clusters create "gke-vpc1-us-central-1" \
#     --labels path="$GKE_LABEL" \
#     --project "$PROJECT_ID" \
#     --location "${VPC1_SUBNET_REGION_USC1}" \
#     --network  "${VPC_1_NAME}" \
#     --subnetwork "${VPC1_SUBNET_NAME_USC1}" 
# 
# 
# gcloud container clusters create "gke-vpc1-us-west-1" \
#     --labels path="$GKE_LABEL" \
#     --project "$PROJECT_ID" \
#     --location "${VPC1_SUBNET_REGION_USW1}" \
#     --network  "${VPC_1_NAME}" \
#     --subnetwork "${VPC1_SUBNET_NAME_USW1}" 
# 
# 
# gcloud container clusters create "gke-vpc1-us-east-1" \
#     --labels path="$GKE_LABEL" \
#     --project "$PROJECT_ID" \
#     --location "${VPC1_SUBNET_REGION_USE1}" \
#     --network  "${VPC_1_NAME}" \
#     --subnetwork "${VPC1_SUBNET_NAME_USE1}" 





####Configs Flags of interest:

# --no-enable-insecure-kubelet-readonly-port : new recommended best practice that is not a default
#   Clusters created without it will show:
#   Note: The Kubelet readonly port (10255) is now deprecated. Please update your workloads to use the recommended alternatives. See https://cloud.google.com/kubernetes-engine/docs/how-to/disable-kubelet-readonly-port for ways to check usage and for migration instructions.



#Default, + Private: GKE DNS, public endpoint (and private endpoint)
        #     --enable-private-nodes \
        # Will ave GKE DNS endpoint as well as GKE Public endpoint
        # for access of ip-based public endpoint, defaults to "--no-enable-master-authorized-networks ",i.e., everyone can access the public endpoint. Would have to use --enable-master-authorized-networks + --master-authorized-networks to whitelist.



printf "▶️  Step: \033[1;32m'GKE Cluster 1 Deployment.'\033[0m Press Enter to Continue\n"
if [[ "$AUTO_APPROVE" != "true" ]]; then
    read -r -p ""
fi

#Default, Just GKE DNS, No ip-based endpoints
        #     --enable-private-nodes \
        #     --no-enable-ip-access
        #     --enable-dns-access







# gcloud container clusters create "gke01" \
#     --labels path="$GKE_LABEL" \
#     --project "$PROJECT_ID" \
#     --location "${VPC1_SUBNET_REGION_USC1}" \
#     --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
#     --network  "${VPC_1_NAME}" \
#     --subnetwork "${VPC1_SUBNET_NAME_USC1}" \
#     --enable-private-nodes --enable-ip-alias \
#     --enable-dns-access \
#     --no-enable-ip-access
#     # --no-enable-master-authorized-networks \
#     # --no-enable-private-endpoint # no public endpoint

# From above basic template but with new flags:

# # 1. Create the Cluster with an empty placeholder pool
# CLUSTER_NAME="gke01"
# gcloud container clusters create "$CLUSTER_NAME" \
#     --project "$PROJECT_ID" \
#     --location "${VPC1_SUBNET_REGION_USC1}" \
#     --machine-type "e2-medium" \
#     --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
#     --network "${VPC_1_NAME}" \
#     --subnetwork "${VPC1_SUBNET_NAME_USC1}" \
#     --enable-private-nodes \
#     --enable-ip-alias \
#     --enable-dns-access \
#     --no-enable-ip-access \
#     --service-account "$GKE_NODE_SA_EMAIL" \
#     --workload-pool "$PROJECT_ID.svc.id.goog" \
#     --num-nodes "1"  # Creates cluster with 0 nodes in the default-pool
# 
# # 2. Create the Dedicated System Node Pool
# gcloud container node-pools create "pool-system" \
#   --cluster "$CLUSTER_NAME" \
#   --machine-type "e2-medium" \
#   --location "${VPC1_SUBNET_REGION_USC1}" \
#   --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
#   --num-nodes "3" \
#   --node-taints components.gke.io/gke-managed-components=true:NoSchedule \
#   --node-labels resource-type=system,env=dev \
#   --service-account "$GKE_NODE_SA_EMAIL"
# 
# # 3. Create the Workload Node Pool (Fixed Cluster Name)
# gcloud container node-pools create "pool-wrkld-01" \
#   --cluster "$CLUSTER_NAME" \
#   --location "${VPC1_SUBNET_REGION_USC1}" \
#   --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
#   --machine-type "n2-standard-2" \
#   --num-nodes "1" \
#   --node-labels resource-type=wrklds,env=dev \
#   --service-account "$GKE_NODE_SA_EMAIL"
# 
# # 4. (Optional) Remove the empty default-pool to keep it clean
# gcloud container node-pools delete "default-pool" --cluster "$CLUSTER_NAME" --location "${VPC1_SUBNET_REGION_USC1}" --quiet
# 








printf "    ✅ Cluster \033[1;32m$GKE_CLUSTER_NAME\033[0m Created.\n"


printf "    ✅ All GKE Clusters setup complete. Press Enter to Continue"

if [[ "$AUTO_APPROVE" != "true" ]]; then
    read -r -p ""
fi

# Write Cluster URL to file
echo "https://console.cloud.google.com/kubernetes/list/overview?project=$PROJECT_ID" > cluster-url.txt
echo "https://console.cloud.google.com/networking/networks/list?project=$PROJECT_ID" > vpc-url.txt

printf "    ℹ️  Cluster URL saved to: \033[1;32mcluster-url.txt\033[0m\n"

#Chrome's command line doesn't recognize your email address (the "Display Name") directly. Instead, it uses a folder name like Default, Profile 1, or Profile 2.
# To get this working, we need to find that folder name first.

# Step 1: Find your Profile Directory Name
# Open Chrome using the profile for admin@meillier.altostrat.com.
# In the address bar, type chrome://version and hit Enter.
# Look for the row labeled Profile Path.
# The very last part of that path is what we need (e.g., Profile 3).
# 
# Step 2: Use the Command
# Once you have that name (let's assume it's Profile 3), you can't use the simple open -a command because it doesn't pass arguments correctly to the Chrome binary for profiles. You have to call the Chrome application binary directly.
# 
# Use this command:
# "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --profile-directory="Profile 3" "$(cat vpc-url.txt)"

"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --profile-directory="Profile 4" "$(cat cluster-url.txt)"

# open -a "Google Chrome" $(cat cluster-url.txt)
