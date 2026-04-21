#!/bin/bash



printf "🔄 Performing Environment cleanup tasks ...\n"
sleep 1

#clearing potential remnant/lingering billing_id file:
printf "    🧹 Cleaning  \033[1;32m'billing_id file'\033[0m if any\n"
BILLING_ID_FILE=".billing_id"
if [ -f "$BILLING_ID_FILE" ]; then
    rm "$BILLING_ID_FILE"       
fi
sleep 1



#Clear gcloud configs:
declare -a gcloud_properties=(
    "core/project"
    "compute/region"
    "compute/zone"
)
for gcloud_property in "${gcloud_properties[@]}"
do
    printf "    🧹 Cleaning  \033[1;32m'$gcloud_property'\033[0m\n"
    if [ -n "$(gcloud config get-value $gcloud_property 2>/dev/null)" ]; then gcloud config unset $gcloud_property >/dev/null 2>&1; fi
done




#Clear Variables
declare -a runtime_variables=(
    "GCP_REGION"
    "GCP_ZONE"
    "PROJECT_ID"
    "PROJECT_NAME_PREFIX"
    "RANDOM_SUFFIX"
    "PROJECT_NAME"
    "CLOUDSDK_CORE_PROJECT"    
)
for runtime_variable in "${runtime_variables[@]}"; do
    if [ -n "${!runtime_variable}" ]; then 
        printf "    🧹 Cleaning  \033[1;32m'$runtime_variable'\033[0m\n"
        #printf "Unsetting %s variable (was: %s)\n" "${runtime_variable}" "${!runtime_variable}"
        unset "${runtime_variable}" 
    fi
done



# Clear Application Default Credentials quota project
printf "    🧹 Setting   \033[1;32m'quota-project'\033[0m to empty string\n"
gcloud auth application-default set-quota-project "" >/dev/null 2>&1 || true


printf "    ✅ Environment cleanup complete\n"
printf "\n"