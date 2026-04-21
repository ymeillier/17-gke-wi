#!/bin/bash


VARS_FILE="./.variables"
source $VARS_FILE
gcloud config set project $PROJECT_ID
gcloud auth application-default set-quota-project "$PROJECT_ID"
gcloud config set billing/quota_project "$PROJECT_ID"

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


# Add the additional commands to run after the base lab was setup (project and VPC, vpc subnets,... if chose to)

#Note: If lab has you create additional variables, we want them to be saved in our .variables file to reload them after starting a new shell.
    ## For example:
        #save_var export ACP_REPO_DIR="$(pwd)"
    ## or manually:
        # echo 'export ACP_REPO_DIR="'$PWD'"' >> ../gcloud/.variables



















## Done in main deploy script  00-depoy.sh
# # 3. Dedicated Service Account for GKE Nodes
#     printf "    Creating Dedicated Service Account for GKE Nodes...\n"
# 
#     save_var GKE_NODE_SA_NAME "gke-custom-sa"
# 
#     save_var GKE_NODE_SA_EMAIL "${GKE_NODE_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
# 
#     # Check if SA exists
#     if ! gcloud iam service-accounts describe "$GKE_NODE_SA_EMAIL" --project "$PROJECT_ID" > /dev/null 2>&1; then
#         gcloud iam service-accounts create "$GKE_NODE_SA_NAME" \
#             --display-name="GKE Node Service Account" \
#             --project "$PROJECT_ID" \
#             --quiet
#         printf "    ✅ Created Service Account: \033[1;32m$GKE_NODE_SA_EMAIL\033[0m\n"
#     else
#         printf "    ℹ️  Service Account \033[1;32m$GKE_NODE_SA_EMAIL\033[0m already exists.\n"
#     fi
# 
#     # Wait for Service Account to be propagated
#     printf "    ⏳ Waiting for Service Account propagation...\n"
#     until gcloud iam service-accounts describe "$GKE_NODE_SA_EMAIL" --project "$PROJECT_ID" > /dev/null 2>&1; do
#         echo -n "."
#         sleep 2
#     done
#     printf "\n"
#     # Additional buffer for IAM consistency across services
#     sleep 10
# 
#     # Assign roles/container.defaultNodeServiceAccount
#     printf "    Assigning roles/container.defaultNodeServiceAccount to gke custom SA...\n"
#     ./scripts/iam-policy-add-project.sh "$PROJECT_ID" "serviceAccount:$GKE_NODE_SA_EMAIL" "roles/container.defaultNodeServiceAccount"
#     
#     # About artifactregistry.reader:
#         # If your Artifact Registry is in the same project as your GKE cluster, nodes can often pull images by default via internal service agent permissions.
#         # If you are pulling from a different project or have a highly restricted environment, you must explicitly add the roles/artifactregistry.reader role to your custom service account.
#     printf "    Assigning roles/artifactregistry.reader to gke custom SA...\n"
#     ./scripts/iam-policy-add-project.sh "$PROJECT_ID" "serviceAccount:$GKE_NODE_SA_EMAIL" "roles/artifactregistry.reader"
# 
# 















 
# #Default GCE service account permissions:
# 
MEMBER="serviceAccount:728506269517-compute@developer.gserviceaccount.com"
gcloud projects get-ancestors-iam-policy $PROJECT_ID \
--flatten policy.bindings[].members \
--filter policy.bindings.members:$MEMBER \
--format="table[box](policy.bindings.role,policy.bindings.members,id)"

# Even with the automatic grant enabled, modern GKE best practices (and some automated setups) expect you to grant roles manually. To make your nodes functional, you must explicitly grant the roles/container.defaultNodeServiceAccount ro
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=$MEMBER \
    --role="roles/container.defaultNodeServiceAccount"





































# Create Cluster to replicate the topology covered in the documentation: https://docs.cloud.google.com/kubernetes-engine/docs/concepts/workload-identity#identity_sameness

# GKE01: 
CLUSTER_NAME="cluster-a"
gcloud container clusters create "$CLUSTER_NAME" \
    --project "$PROJECT_ID" \
    --machine-type "e2-medium" \
    --location "${VPC1_SUBNET_REGION_USC1}" \
    --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
    --network "${VPC_1_NAME}" \
    --subnetwork "${VPC1_SUBNET_NAME_USC1}" \
    --enable-private-nodes \
    --enable-ip-alias \
    --enable-dns-access \
    --no-enable-ip-access \
    --service-account "$GKE_NODE_SA_EMAIL" \
    --workload-pool "$PROJECT_ID.svc.id.goog" \
    --num-nodes "1"

# 2. Create the Dedicated System Node Pool
gcloud container node-pools create "pool-system" \
  --cluster "$CLUSTER_NAME" \
  --machine-type "e2-medium" \
  --location "${VPC1_SUBNET_REGION_USC1}" \
  --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
  --num-nodes "3" \
  --node-taints components.gke.io/gke-managed-components=true:NoSchedule \
  --node-labels resource-type=system,env=dev \
  --service-account "$GKE_NODE_SA_EMAIL"

# 3. Create the Workload Node Pool (Fixed Cluster Name)
gcloud container node-pools create "pool-wrkld-01" \
  --cluster "$CLUSTER_NAME" \
  --location "${VPC1_SUBNET_REGION_USC1}" \
  --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
  --machine-type "n2-standard-2" \
  --num-nodes "1" \
  --node-labels resource-type=wrklds,env=dev \
  --service-account "$GKE_NODE_SA_EMAIL"

# 4. (Optional) Remove the empty default-pool to keep it clean
gcloud container node-pools delete "default-pool" --cluster "$CLUSTER_NAME" --location "${VPC1_SUBNET_REGION_USC1}" --quiet

printf "    ✅ Cluster \033[1;32m$GKE_CLUSTER_NAME\033[0m Created.\n"




# Second cluster configured the same was as gke-01: to show how same namespace name and a WI IAM binding using namespace Principal will share access privileges.
# https://docs.cloud.google.com/kubernetes-engine/docs/concepts/workload-identity#identity_sameness
CLUSTER_NAME="cluster-b"
gcloud container clusters create "$CLUSTER_NAME" \
    --project "$PROJECT_ID" \
    --machine-type "e2-medium" \
    --location "${VPC1_SUBNET_REGION_USC1}" \
    --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
    --network "${VPC_1_NAME}" \
    --subnetwork "${VPC1_SUBNET_NAME_USC1}" \
    --enable-private-nodes \
    --enable-ip-alias \
    --enable-dns-access \
    --no-enable-ip-access \
    --service-account "$GKE_NODE_SA_EMAIL" \
    --workload-pool "$PROJECT_ID.svc.id.goog" \
    --num-nodes "1"
    # Creates cluster with 0 nodes in the default-pool

# 2. Create the Dedicated System Node Pool
gcloud container node-pools create "pool-system" \
  --cluster "$CLUSTER_NAME" \
  --machine-type "e2-medium" \
  --location "${VPC1_SUBNET_REGION_USC1}" \
  --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
  --num-nodes "3" \
  --node-taints components.gke.io/gke-managed-components=true:NoSchedule \
  --node-labels resource-type=system,env=dev \
  --service-account "$GKE_NODE_SA_EMAIL"

# 3. Create the Workload Node Pool (Fixed Cluster Name)
gcloud container node-pools create "pool-wrkld-01" \
  --cluster "$CLUSTER_NAME" \
  --location "${VPC1_SUBNET_REGION_USC1}" \
  --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
  --machine-type "n2-standard-2" \
  --num-nodes "1" \
  --node-labels resource-type=wrklds,env=dev \
  --service-account "$GKE_NODE_SA_EMAIL"

# 4. (Optional) Remove the empty default-pool to keep it clean
gcloud container node-pools delete "default-pool" --cluster "$CLUSTER_NAME" --location "${VPC1_SUBNET_REGION_USC1}" --quiet

printf "    ✅ Cluster \033[1;32m$GKE_CLUSTER_NAME\033[0m Created.\n"



























# # GKE no custom SA and WI enabled (metadata server )- but if no WI binding with a KSA principal falls back to default SA permissions for access.
# Permissive service account


# Permissive Service Account for GKE Nodes
    printf "    Creating Dedicated Service Account for GKE Nodes...\n"

    save_var GKE_PERMISSIVE_SA_NAME "gke-permissive-sa"

    save_var GKE_PERMISSIVE_SA_EMAIL "${GKE_PERMISSIVE_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

    # Check if SA exists
    if ! gcloud iam service-accounts describe "$GKE_PERMISSIVE_SA_EMAIL" --project "$PROJECT_ID" > /dev/null 2>&1; then
        gcloud iam service-accounts create "$GKE_PERMISSIVE_SA_NAME" \
            --display-name="GKE Permissive Service Account" \
            --project "$PROJECT_ID" \
            --quiet
        printf "    ✅ Created Service Account: \033[1;32m$GKE_PERMISSIVE_SA_EMAIL\033[0m\n"
    else
        printf "    ℹ️  Service Account \033[1;32m$GKE_PERMISSIVEE_SA_EMAIL\033[0m already exists.\n"
    fi

    # Wait for Service Account to be propagated
    printf "    ⏳ Waiting for Service Account propagation...\n"
    until gcloud iam service-accounts describe "$GKE_PERMISSIVE_SA_EMAIL" --project "$PROJECT_ID" > /dev/null 2>&1; do
        echo -n "."
        sleep 2
    done
    printf "\n"
    # Additional buffer for IAM consistency across services
    sleep 10

    #     # Assign roles/container.defaultNodeServiceAccount
    #     printf "    Assigning roles/container.defaultNodeServiceAccount to gke custom SA...\n"
    #     ./scripts/iam-policy-add-project.sh "$PROJECT_ID" "serviceAccount:$GKE_PERMISSIVE_SA_EMAIL" "roles/container.defaultNodeServiceAccount"
    #     
    # 
    #     # About artifactregistry.reader:
    #         # If your Artifact Registry is in the same project as your GKE cluster, nodes can often pull images by default via internal service agent permissions.
    #         # If you are pulling from a different project or have a highly restricted environment, you must explicitly add the roles/artifactregistry.reader role to your custom service account.
    #     printf "    Assigning roles/artifactregistry.reader to gke permissive SA...\n"
    #     ./scripts/iam-policy-add-project.sh "$PROJECT_ID" "serviceAccount:$GKE_PERMISSIVE_SA_EMAIL" "roles/artifactregistry.reader"


    # Editor Role: purposedly assign very permissive role
    printf "    Assigning roles/editor to gke permissive SA...\n"
    ./scripts/iam-policy-add-project.sh "$PROJECT_ID" "serviceAccount:$GKE_PERMISSIVE_SA_EMAIL" "roles/editor"


    










# Cluster that use a permissive SA to showcase how we leverage fallback access method (node SA) when WI SA fails to connect.
CLUSTER_NAME="cluster-fallback"
gcloud container clusters create "$CLUSTER_NAME" \
    --project "$PROJECT_ID" \
    --machine-type "e2-medium" \
    --location "${VPC1_SUBNET_REGION_USC1}" \
    --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
    --network "${VPC_1_NAME}" \
    --subnetwork "${VPC1_SUBNET_NAME_USC1}" \
    --enable-private-nodes \
    --enable-ip-alias \
    --enable-dns-access \
    --no-enable-ip-access \
    --workload-pool "$PROJECT_ID.svc.id.goog" \
    --service-account "$GKE_PERMISSIVE_SA_EMAIL" \
    --num-nodes "1"
    # Creates cluster with 0 nodes in the default-pool

# 2. Create the Dedicated System Node Pool
gcloud container node-pools create "pool-system" \
  --cluster "$CLUSTER_NAME" \
  --machine-type "e2-medium" \
  --location "${VPC1_SUBNET_REGION_USC1}" \
  --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
  --num-nodes "3" \
  --node-taints components.gke.io/gke-managed-components=true:NoSchedule \
  --node-labels resource-type=system,env=dev \
  --service-account "$GKE_PERMISSIVE_SA_EMAIL"

# 3. Create the Workload Node Pool (Fixed Cluster Name)
gcloud container node-pools create "pool-wrkld-01" \
  --cluster "$CLUSTER_NAME" \
  --location "${VPC1_SUBNET_REGION_USC1}" \
  --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
  --machine-type "n2-standard-2" \
  --num-nodes "1" \
  --node-labels resource-type=wrklds,env=dev \
  --service-account "$GKE_PERMISSIVE_SA_EMAIL"

# 4. (Optional) Remove the empty default-pool to keep it clean
gcloud container node-pools delete "default-pool" --cluster "$CLUSTER_NAME" --location "${VPC1_SUBNET_REGION_USC1}" --quiet

printf "    ✅ Cluster \033[1;32m$GKE_CLUSTER_NAME\033[0m Created.\n"














































#### Creating cluster to demo Fleet
# GKE01: 
CLUSTER_NAME="fleet-gke01"
gcloud container clusters create "$CLUSTER_NAME" \
    --project "$PROJECT_ID" \
    --machine-type "e2-medium" \
    --location "${VPC1_SUBNET_REGION_USC1}" \
    --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
    --network "${VPC_1_NAME}" \
    --subnetwork "${VPC1_SUBNET_NAME_USC1}" \
    --enable-private-nodes \
    --enable-ip-alias \
    --enable-dns-access \
    --no-enable-ip-access \
    --service-account "$GKE_NODE_SA_EMAIL" \
    --workload-pool "$PROJECT_ID.svc.id.goog" \
    --num-nodes "1"
    # Creates cluster with 0 nodes in the default-pool

# 2. Create the Dedicated System Node Pool
gcloud container node-pools create "pool-system" \
  --cluster "$CLUSTER_NAME" \
  --machine-type "e2-medium" \
  --location "${VPC1_SUBNET_REGION_USC1}" \
  --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
  --num-nodes "3" \
  --node-taints components.gke.io/gke-managed-components=true:NoSchedule \
  --node-labels resource-type=system,env=dev \
  --service-account "$GKE_NODE_SA_EMAIL"

# 3. Create the Workload Node Pool (Fixed Cluster Name)
gcloud container node-pools create "pool-wrkld-01" \
  --cluster "$CLUSTER_NAME" \
  --location "${VPC1_SUBNET_REGION_USC1}" \
  --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
  --machine-type "n2-standard-2" \
  --num-nodes "1" \
  --node-labels resource-type=wrklds,env=dev \
  --service-account "$GKE_NODE_SA_EMAIL"

# 4. (Optional) Remove the empty default-pool to keep it clean
gcloud container node-pools delete "default-pool" --cluster "$CLUSTER_NAME" --location "${VPC1_SUBNET_REGION_USC1}" --quiet

printf "    ✅ Cluster \033[1;32m$GKE_CLUSTER_NAME\033[0m Created.\n"




# GKE01: 
CLUSTER_NAME="fleet-gke02"
gcloud container clusters create "$CLUSTER_NAME" \
    --project "$PROJECT_ID" \
    --machine-type "e2-medium" \
    --location "${VPC1_SUBNET_REGION_USC1}" \
    --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
    --network "${VPC_1_NAME}" \
    --subnetwork "${VPC1_SUBNET_NAME_USC1}" \
    --enable-private-nodes \
    --enable-ip-alias \
    --enable-dns-access \
    --no-enable-ip-access \
    --service-account "$GKE_NODE_SA_EMAIL" \
    --workload-pool "$PROJECT_ID.svc.id.goog" \
    --num-nodes "1"
    # Creates cluster with 0 nodes in the default-pool

# 2. Create the Dedicated System Node Pool
gcloud container node-pools create "pool-system" \
  --cluster "$CLUSTER_NAME" \
  --machine-type "e2-medium" \
  --location "${VPC1_SUBNET_REGION_USC1}" \
  --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
  --num-nodes "3" \
  --node-taints components.gke.io/gke-managed-components=true:NoSchedule \
  --node-labels resource-type=system,env=dev \
  --service-account "$GKE_NODE_SA_EMAIL"

# 3. Create the Workload Node Pool (Fixed Cluster Name)
gcloud container node-pools create "pool-wrkld-01" \
  --cluster "$CLUSTER_NAME" \
  --location "${VPC1_SUBNET_REGION_USC1}" \
  --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
  --machine-type "n2-standard-2" \
  --num-nodes "1" \
  --node-labels resource-type=wrklds,env=dev \
  --service-account "$GKE_NODE_SA_EMAIL"

# 4. (Optional) Remove the empty default-pool to keep it clean
gcloud container node-pools delete "default-pool" --cluster "$CLUSTER_NAME" --location "${VPC1_SUBNET_REGION_USC1}" --quiet

printf "    ✅ Cluster \033[1;32m$GKE_CLUSTER_NAME\033[0m Created.\n"





# GKE01: 
CLUSTER_NAME="fleet-gke03"
gcloud container clusters create "$CLUSTER_NAME" \
    --project "$PROJECT_ID" \
    --machine-type "e2-medium" \
    --location "${VPC1_SUBNET_REGION_USC1}" \
    --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
    --network "${VPC_1_NAME}" \
    --subnetwork "${VPC1_SUBNET_NAME_USC1}" \
    --enable-private-nodes \
    --enable-ip-alias \
    --enable-dns-access \
    --no-enable-ip-access \
    --service-account "$GKE_NODE_SA_EMAIL" \
    --workload-pool "$PROJECT_ID.svc.id.goog" \
    --num-nodes "1"
    # Creates cluster with 0 nodes in the default-pool

# 2. Create the Dedicated System Node Pool
gcloud container node-pools create "pool-system" \
  --cluster "$CLUSTER_NAME" \
  --machine-type "e2-medium" \
  --location "${VPC1_SUBNET_REGION_USC1}" \
  --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
  --num-nodes "3" \
  --node-taints components.gke.io/gke-managed-components=true:NoSchedule \
  --node-labels resource-type=system,env=dev \
  --service-account "$GKE_NODE_SA_EMAIL"

# 3. Create the Workload Node Pool (Fixed Cluster Name)
gcloud container node-pools create "pool-wrkld-01" \
  --cluster "$CLUSTER_NAME" \
  --location "${VPC1_SUBNET_REGION_USC1}" \
  --node-locations "${VPC1_SUBNET_REGION_USC1}-a" \
  --machine-type "n2-standard-2" \
  --num-nodes "1" \
  --node-labels resource-type=wrklds,env=dev \
  --service-account "$GKE_NODE_SA_EMAIL"

# 4. (Optional) Remove the empty default-pool to keep it clean
gcloud container node-pools delete "default-pool" --cluster "$CLUSTER_NAME" --location "${VPC1_SUBNET_REGION_USC1}" --quiet

printf "    ✅ Cluster \033[1;32m$GKE_CLUSTER_NAME\033[0m Created.\n"


































# Create the policy file
cat <<EOF > policy.yaml
name: projects/$PROJECT_ID/policies/iam.automaticIamGrantsForDefaultServiceAccounts
spec:
  rules:
  - enforce: false
EOF
# not guaranteed the service acount would be created with roles even.
# Apply the file
gcloud org-policies set-policy policy.yaml
















#######################################################################################################################################################################
#######################################################################################################################################################################
################################################ WI ################################################################################################################


#Verify identity providers (GKE clusters' metadata servers) registered to the WI pool
# gcloud iam workload-identity-pools providers list \
# --location="global" \
# --workload-identity-pool="${PROJECT_ID}.svc.id.goog" \
# --project="$PROJECT_ID"
# ---> not meant to work for a google managed pool.




# Tutorial/demo:
    # - IAM gives a Principal (pods that use a speficic KS, pods in a NS, pods in a cluster) access to a google cloud resource (e.g. read access to bucket) 
    #To provide access with Workload Identity Federation for GKE, you create an IAM allow policy that grants access on a specific Google Cloud resource to a principal that corresponds to your application's identity. For example, you could give read permissions on a Cloud Storage bucket to all Pods that use the database-reader Kubernetes ServiceAccoun

    #Can use Conditional IAM policies, e.g. time expiration or resource has specific tag (https://docs.cloud.google.com/kubernetes-engine/docs/concepts/workload-identity#use-iam-conditions)

    # Principal identifier:
        ## All pods hat use a specific kubernetes SA
        ## All pods in a namespace
        ## All pods in a specific cluster
    
    # Restrictions: https://docs.cloud.google.com/kubernetes-engine/docs/concepts/workload-identity#restrictions




# See metadata server: a system pod so does not show in pods. 
    # kubectl get nodes -o custom-columns="NAME:.metadata.name,WORKLOAD_METADATA:.metadata.annotations['container\.googleapis\.com/instance_id']"
    # meillier@meillier-macbookpro gcloud % kubectl get nodes -o custom-columns="NAME:.metadata.name,WORKLOAD_METADATA:.metadata.annotations['container\.googleapis\.com/instance_id']"
    # NAME                                        WORKLOAD_METADATA
    # gke-cluster-a-pool-system-a0710da7-4633     277641480954435650
    # gke-cluster-a-pool-system-a0710da7-4sbp     8605832553958725698
    # gke-cluster-a-pool-system-a0710da7-qz66     4171377450467711042
    # gke-cluster-a-pool-wrkld-01-556c165a-9gdb   7708886753686575584




# Create namespace

gcloud container clusters get-credentials cluster-a --location us-central1

NAMESPACE="frontend"
KSA_NAME="front-ksa"
kubectl create namespace $NAMESPACE
kubectl create serviceaccount $KSA_NAME --namespace $NAMESPACE

#kubectl get sa -n frontend



# All Principals that one can use for the scope of the SA are listed here: 
#       https://docs.cloud.google.com/kubernetes-engine/docs/concepts/workload-identity#use-iam-conditions
#       https://docs.cloud.google.com/iam/docs/principal-identifiers

MEMBER="principal://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/$NAMESPACE/sa/${KSA_NAME}"
gcloud projects add-iam-policy-binding projects/$PROJECT_ID \
    --role=roles/container.clusterViewer \
    --member=$MEMBER \
    --condition=None


gcloud projects get-ancestors-iam-policy "$PROJECT_ID" \
--flatten='policy.bindings[].members' \
--filter='policy.bindings.members="'"$MEMBER"'"' \
--format='table[box](policy.bindings.role, policy.bindings.members, id)'




#Test on empty cloud storage bucket access
BUCKET="bucket-wi-05713"
gcloud storage buckets create gs://${BUCKET}

#Grant storage object viewer to the service account (KSA principal)
gcloud storage buckets add-iam-policy-binding gs://${BUCKET} \
    --role=roles/storage.objectViewer \
    --member=$MEMBER \
    --condition=None


# cat <<EOF > test-pod.yaml
# apiVersion: v1
# kind: Pod
# metadata:
#   name: test-pod
#   namespace: $NAMESPACE
# spec:
#   serviceAccountName: $KSA_NAME
#   containers:
#   - name: test-pod
#     image: google/cloud-sdk:slim
#     command: ["sleep","infinity"]
#     resources:
#       requests:
#         cpu: 500m
#         memory: 512Mi
#         ephemeral-storage: 10Mi
#   nodeSelector:
#     iam.gke.io/gke-metadata-server-enabled: "true"
# EOF



kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: $NAMESPACE
spec:
  serviceAccountName: $KSA_NAME
  containers:
  - name: test-pod
    image: google/cloud-sdk:slim
    command: ["sleep","infinity"]
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
        ephemeral-storage: 10Mi
  nodeSelector:
    iam.gke.io/gke-metadata-server-enabled: "true"
EOF


kubectl exec -it pods/test-pod --namespace=$NAMESPACE -- /bin/bash

#use bucket name as variable not known
curl -X GET -H "Authorization: Bearer $(gcloud auth print-access-token)" "https://storage.googleapis.com/storage/v1/b/bucket-wi-05713/o"












NAMESPACE="backend"
KSA_NAME="back-ksa"
kubectl create namespace $NAMESPACE
kubectl create serviceaccount back-ksa --namespace $NAMESPACE


kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-backend
  namespace: $NAMESPACE
spec:
  serviceAccountName: $KSA_NAME
  containers:
  - name: test-pod
    image: google/cloud-sdk:slim
    command: ["sleep","infinity"]
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
        ephemeral-storage: 10Mi
  nodeSelector:
    iam.gke.io/gke-metadata-server-enabled: "true"
EOF


kubectl exec -it pods/test-pod-backend --namespace=$NAMESPACE -- /bin/bash

#use bucket name as variable not known
curl -X GET -H "Authorization: Bearer $(gcloud auth print-access-token)" "https://storage.googleapis.com/storage/v1/b/bucket-wi-05713/o"


## --> indeed forbidden


































## Shared namespaces:

BUCKET="bucket-wi-05713-backend"
gcloud storage buckets create gs://${BUCKET}
NAMESPACE="backend"




#Principal now would be set on the namespace
# instead of KSA based PI: 
# MEMBER="principal://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/$NAMESPACE/sa/${KSA_NAME}"

MEMBER="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/namespace/$NAMESPACE"
# gcloud storage buckets add-iam-policy-binding gs://${BUCKET} \
#     --role=roles/storage.objectViewer \
#     --member=$MEMBER \
#     --condition=None


## Error: 
# The reason your command worked for the KSA principal but failed for the Namespace principalSet is that the gcloud storage tool (which uses the Storage-specific API) does not yet fully support the IAM v2 principalSet:// syntax for direct bucket bindings.
# While Workload Identity Federation for GKE allows these new "direct" identifiers, some older CLI components still only recognize the principal:// (singular) or the legacy serviceAccount: formats.

# gcloud projects add-iam-policy-binding "$PROJECT_ID" \
#     --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/namespace/$NAMESPACE" \
#     --role="roles/storage.objectViewer" \
#     --condition='expression=resource.name.startsWith("projects/_/buckets/'"${BUCKET}"'"),title=allow_namespace_access'


gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/namespace/backend" \
    --role="roles/storage.objectViewer" \
    --condition="expression=resource.name.startsWith(\"projects/_/buckets/${BUCKET}\"),title=allow_backend_namespace_to_bucket"


kubectl exec -it pods/test-pod-backend --namespace=$NAMESPACE -- /bin/bash

#use bucket name as variable not known
curl -X GET -H "Authorization: Bearer $(gcloud auth print-access-token)" "https://storage.googleapis.com/storage/v1/b/bucket-wi-05713-backend/o"








## Now in second cluster:
gcloud container clusters get-credentials cluster-b --location us-central1

NAMESPACE="backend"
KSA_NAME="back-ksa2"
kubectl create namespace $NAMESPACE
kubectl create serviceaccount $KSA_NAME --namespace $NAMESPACE


kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-backend2
  namespace: $NAMESPACE
spec:
  serviceAccountName: $KSA_NAME
  containers:
  - name: test-pod
    image: google/cloud-sdk:slim
    command: ["sleep","infinity"]
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
        ephemeral-storage: 10Mi
  nodeSelector:
    iam.gke.io/gke-metadata-server-enabled: "true"
EOF


#without assigning any binding:
kubectl exec -it pods/test-pod-backend2 --namespace=$NAMESPACE -- /bin/bash

#use bucket name as variable not known
curl -X GET -H "Authorization: Bearer $(gcloud auth print-access-token)" "https://storage.googleapis.com/storage/v1/b/bucket-wi-05713-backend/o"


### ---> and works.
























#######################################################################################################################################################################
#######################################################################################################################################################################
################################################ FLEET ################################################################################################################





# REgister the clusters to the fleet project:


# Create the gcp-sa-gkehub service account
    # To grant gcp-sa-gkehub the gkehub.serviceAgent role, first ensure that this service account exists in the fleet host project. If you have registered clusters in this fleet project before, then this service account should exist already. 


# Define your fleet project ID based on your suffix logic



# GRant permission to register a cluster into a different project (https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/before-you-begin/gke#gke-cross-project)
gcloud projects get-iam-policy $PROJECT_ID_FLEET | grep gcp-sa-gkehub
    # --> Need fleet to have been created on the fleet project. Output shows:
    #     - serviceAccount:service-1076653660692@gcp-sa-gkehub.iam.gserviceaccount.com
    #
    #or use command:
    # ##gcp-sa-gkehub sain fleet host project: managed so not listed by gcloud iam service accounts list
    # gcloud projects get-iam-policy $PROJECT_ID_FLEET \
    #     --flatten="bindings[].members" \
    #     --filter="bindings.members ~ gcp-sa-gkehub"
    #
    #
    #
    # # If the fleet host project gcp-sa-gkehub has the required roles in your cluster's project, it should appear in the output in the form service-[FLEET_HOST-PROJECT-NUMBER]@gcp-sa-gkehub.iam.gserviceaccount.com
    # gcloud beta services identity create --service=gkehub.googleapis.com --project=$PROJECT_ID_FLEET
    #     # --> gcloud beta services identity create --service=gkehub.googleapis.com --project=$PROJECT_ID_FLEET
    #     # --> Service identity created: service-1076653660692@gcp-sa-gkehub.iam.gserviceaccount.com



# Fleet GKE HUB service Agent iam policy bindings:
#The most critical part of cross-project registration is granting permissions to the GKE Hub Service Agent of your fleet project so it can manage your cluster.

# 2. Grant Permissions to fleet project GKE HUB service AGENT to manage other clusters (https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/before-you-begin/gke#gke-cross-project)

MEMBER="serviceAccount:service-${PROJECT_NUMBER_FLEET}@gcp-sa-gkehub.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding "${PROJECT_ID_FLEET}" \
  --member "serviceAccount:service-${PROJECT_NUMBER_FLEET}@gcp-sa-gkehub.iam.gserviceaccount.com" \
  --role roles/gkehub.serviceAgent

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member ${MEMBER} \
  --role roles/gkehub.serviceAgent

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member ${MEMBER} \
  --role roles/gkehub.crossProjectServiceAgent

#Validate:
#gcloud projects get-iam-policy $PROJECT_ID | grep -E '^|gkehub.serviceAgent|gkehub.crossProjectServiceAgent|gcp-sa-gkehub'

gcloud projects get-ancestors-iam-policy "$PROJECT_ID" \
--flatten="policy.bindings[].members" \
--filter="policy.bindings.members:$MEMBER" \
--format="table[box](policy.bindings.role,policy.bindings.members,id,type)"






# Register the cluster to the cross-project fleet (https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/register/gke)
# https://docs.cloud.google.com/kubernetes-engine/fleet-management/docs/register/gke#register_an_existing_cluster

# To its project fleet: 
#       gcloud container clusters update CLUSTER_NAME --enable-fleet
# To its project fleet: as lightweight membership: 
#       gcloud container clusters update CLUSTER_NAME --enable-fleet --membership-type=LIGHTWEIGHT
# To a remote fleet project (cros project registration)
#       gcloud container clusters update CLUSTER_NAME --fleet-project=PROJECT_ID_OR_NUMBER
# To a remote fleet project as lightweight:
#       gcloud container clusters update CLUSTER_NAME --fleet-project=PROJECT_ID_OR_NUMBER

CLUSTER_NAME="fleet-gke01"
gcloud container clusters update "$CLUSTER_NAME" \
    --project "$PROJECT_ID" \
    --location "${VPC1_SUBNET_REGION_USC1}" \
    --fleet-project "$PROJECT_ID_FLEET"

        # Updating gke01...done.                                                                                                                                                            
        # Updated [https://container.googleapis.com/v1/projects/project-05713/zones/us-central1/clusters/gke01].
        # To inspect the contents of your cluster, go to: https://console.cloud.google.com/kubernetes/workload_/gcloud/us-central1/gke01?project=project-05713


CLUSTER_NAME="fleet-gke02"
gcloud container clusters update "$CLUSTER_NAME" \
    --project "$PROJECT_ID" \
    --location "${VPC1_SUBNET_REGION_USC1}" \
    --fleet-project "$PROJECT_ID_FLEET"




CLUSTER_NAME="fleet-gke03"
gcloud container clusters update "$CLUSTER_NAME" \
    --project "$PROJECT_ID" \
    --location "${VPC1_SUBNET_REGION_USC1}" \
    --fleet-project "$PROJECT_ID_FLEET"



# And now they show up when running the command from the fleet project (gcloud config set properly)
    # gcloud container fleet memberships list
        # NAME   UNIQUE_ID                             LOCATION
        # gke01  86d313da-684c-4e88-a5f3-0d86b854a0c8  us-central1
        # gke02  dd1f3f37-49e7-4d50-acc2-b4b21f3ef589  us-central1

# And Describe
    # gcloud container fleet memberships describe gke01 --project project-05713-fleet
        # authority:
        #   identityProvider: https://gkehub.googleapis.com/projects/project-05713-fleet/locations/us-central1/memberships/gke01
        #   issuer: https://container.googleapis.com/v1/projects/project-05713/locations/us-central1/clusters/gke01
        #   workloadIdentityPool: project-05713-fleet.svc.id.goog
        # clusterTier: STANDARD
        # createTime: '2026-02-24T22:37:30.508064014Z'
        # endpoint:
        #   gkeCluster:
        #     resourceLink: //container.googleapis.com/projects/project-05713/locations/us-central1/clusters/gke01
        #   googleManaged: true
        #   kubernetesMetadata:
        #     kubernetesApiServerVersion: v1.34.3-gke.1245000
        #     memoryMb: 20661
        #     nodeCount: 4
        #     nodeProviderId: gce
        #     updateTime: '2026-02-24T22:43:22.338534067Z'
        #     vcpuCount: 8
        # monitoringConfig:
        #   cluster: gke01
        #   clusterHash: ec2e1952997b4b2b9b8771cb36c3bd4b6b9f53f3da7643a4b12b1e2f9d0bf04f
        #   kubernetesMetricsPrefix: kubernetes.io
        #   location: us-central1
        #   projectId: project-05713
        # name: projects/project-05713-fleet/locations/us-central1/memberships/gke01
        # state:
        #   code: READY
        # uniqueId: 86d313da-684c-4e88-a5f3-0d86b854a0c8
        # updateTime: '2026-02-24T22:43:22.365471228Z'

# in the console, in the fleet project, clusters show up in GKE> Clusters

# However no cluster in the project itself:
    # gcloud container clusters list --project $PROJECT_ID_FLEET









# ### NOTE: unregister clusters
# CLUSTER_NAME="gke01"
# gcloud container clusters update "$CLUSTER_NAME" \
#     --project="$PROJECT_ID" \
#     --location="${VPC1_SUBNET_REGION_USC1}" \
#     --clear-fleet-project
# 
# CLUSTER_NAME="gke02"
# gcloud container clusters update "$CLUSTER_NAME" \
#     --project="$PROJECT_ID" \
#     --location="${VPC1_SUBNET_REGION_USC1}" \
#     --clear-fleet-project
# 
# 
# in fleet project:
# gcloud container fleet memberships unregister "$CLUSTER_NAME" \
#     --project="$PROJECT_ID_FLEET" \
#     --gke-cluster="${VPC1_SUBNET_REGION_USC1}/$CLUSTER_NAME"
# 
# or via cluster update:
# gcloud container clusters update "$CLUSTER_NAME" \
#     --project="$PROJECT_ID" \
#     --location="${VPC1_SUBNET_REGION_USC1}" \
#     --clear-fleet-project









# Connect Gateway for get-credentials:
    # https://docs.cloud.google.com/kubernetes-engine/enterprise/multicluster-management/gateway/setup


# Enable APIs on fleet project:
gcloud services enable --project=$PROJECT_ID_FLEET  \
    connectgateway.googleapis.com \

    # gcloud services enable --project=$PROJECT_ID_FLEET  \
    #     connectgateway.googleapis.com \
    #     gkeconnect.googleapis.com \
    #     gkehub.googleapis.com \
    #     cloudresourcemanager.googleapis.com
































### FLEET SCOPE

gcloud container fleet scopes create team-1 --project=${PROJECT_ID_FLEET}
gcloud container fleet scopes create team-2 --project=${PROJECT_ID_FLEET}
gcloud container fleet scopes create team-3 --project=${PROJECT_ID_FLEET}




gcloud container fleet scopes list --project $PROJECT_ID_FLEET
    # NAME          PROJECT
    # team-1  project-05713-fleet
    # team-2  project-05713-fleet
    # team-3  project-05713-fleet


gcloud container fleet memberships list --project $PROJECT_ID_FLEET
    # NAME         UNIQUE_ID                             LOCATION
    # fleet-gke03  a062fd51-0056-40de-9628-24b85a271f81  us-central1
    # fleet-gke02  0f30aba3-15dd-4963-aa01-c0d359058317  us-central1
    # fleet-gke01  e42d9281-b2aa-45b5-b576-0e58d8907a86  us-central1



# Could have a Fleet-Team-Admin managing these cluster bindings but will do with our overall admin user.


# Team Cluster Bindings:


MEMBERSHIP_NAME=fleet-gke01
SCOPE_NAME=team-1
BINDING=team1-gke01
MEMBERSHIP_LOCATION=us-central1
gcloud container fleet memberships bindings create $BINDING \
  --project $PROJECT_ID_FLEET \
  --membership $MEMBERSHIP_NAME \
  --scope  $SCOPE_NAME \
  --location $MEMBERSHIP_LOCATION

        # meillier@meillier-macbookpro gcloud % gcloud container fleet memberships bindings create $BINDING \
        #   --project $PROJECT_ID_FLEET \
        #   --membership $MEMBERSHIP_NAME \
        #   --scope  $SCOPE_NAME \
        #   --location $MEMBERSHIP_LOCATION
        # Waiting for membership binding to be created...done.

MEMBERSHIP_NAME=fleet-gke02
SCOPE_NAME=team-1
BINDING=team1-gke02
MEMBERSHIP_LOCATION=us-central1
gcloud container fleet memberships bindings create $BINDING \
  --project $PROJECT_ID_FLEET \
  --membership $MEMBERSHIP_NAME \
  --scope  $SCOPE_NAME \
  --location $MEMBERSHIP_LOCATION







MEMBERSHIP_NAME=fleet-gke02
SCOPE_NAME=team-2
BINDING=team2-gke02
MEMBERSHIP_LOCATION=us-central1
gcloud container fleet memberships bindings create $BINDING \
  --project $PROJECT_ID_FLEET \
  --membership $MEMBERSHIP_NAME \
  --scope  $SCOPE_NAME \
  --location $MEMBERSHIP_LOCATION



MEMBERSHIP_NAME=fleet-gke03
SCOPE_NAME=team-2
BINDING=team2-gke03
MEMBERSHIP_LOCATION=us-central1
gcloud container fleet memberships bindings create $BINDING \
  --project $PROJECT_ID_FLEET \
  --membership $MEMBERSHIP_NAME \
  --scope  $SCOPE_NAME \
  --location $MEMBERSHIP_LOCATION





MEMBERSHIP_NAME=fleet-gke01
SCOPE_NAME=team-3
BINDING=team3-gke01
MEMBERSHIP_LOCATION=us-central1
gcloud container fleet memberships bindings create $BINDING \
  --project $PROJECT_ID_FLEET \
  --membership $MEMBERSHIP_NAME \
  --scope  $SCOPE_NAME \
  --location $MEMBERSHIP_LOCATION



MEMBERSHIP_NAME=fleet-gke02
SCOPE_NAME=team-3
BINDING=team3-gke02
MEMBERSHIP_LOCATION=us-central1
gcloud container fleet memberships bindings create $BINDING \
  --project $PROJECT_ID_FLEET \
  --membership $MEMBERSHIP_NAME \
  --scope  $SCOPE_NAME \
  --location $MEMBERSHIP_LOCATION


MEMBERSHIP_NAME=fleet-gke03
SCOPE_NAME=team-3
BINDING=team3-gke03
MEMBERSHIP_LOCATION=us-central1
gcloud container fleet memberships bindings create $BINDING \
  --project $PROJECT_ID_FLEET \
  --membership $MEMBERSHIP_NAME \
  --scope  $SCOPE_NAME \
  --location $MEMBERSHIP_LOCATION



#Then we create the Fleet Team Namespaces

NAMESPACE_NAME=fleet-ns-1
SCOPE=team-1
gcloud container fleet scopes namespaces create $NAMESPACE_NAME \
--scope=$SCOPE \
--project $PROJECT_ID_FLEET


NAMESPACE_NAME=fleet-ns-2
SCOPE=team-1
gcloud container fleet scopes namespaces create $NAMESPACE_NAME \
--scope=$SCOPE \
--project $PROJECT_ID_FLEET


NAMESPACE_NAME=fleet-ns-3
SCOPE=team-1
gcloud container fleet scopes namespaces create $NAMESPACE_NAME \
--scope=$SCOPE \
--project $PROJECT_ID_FLEET





NAMESPACE_NAME=fleet-ns-4
SCOPE=team-2
gcloud container fleet scopes namespaces create $NAMESPACE_NAME \
--scope=$SCOPE \
--project $PROJECT_ID_FLEET

NAMESPACE_NAME=fleet-ns-5
SCOPE=team-2
gcloud container fleet scopes namespaces create $NAMESPACE_NAME \
--scope=$SCOPE \
--project $PROJECT_ID_FLEET





NAMESPACE_NAME=fleet-ns-6
SCOPE=team-3
gcloud container fleet scopes namespaces create $NAMESPACE_NAME \
--scope=$SCOPE \
--project $PROJECT_ID_FLEET












#### Grant tenant admins team rbac roles



EMAIL=fleet-team1-admin@meillier.altostrat.com
ROLE=admin
SCOPE_NAME=team-1
BINDING_NAME=team1-user1-scoperbac

gcloud container fleet scopes rbacrolebindings create $BINDING_NAME \
   --project $PROJECT_ID_FLEET \
   --scope=$SCOPE_NAME \
   --role=$ROLE \
   --user=$EMAIL

# EMAIL=anthos-tenant1-admins@meillier.altostrat.com
# gcloud container fleet scopes rbacrolebindings create $BINDING_NAME \
#    --scope=$SCOPE_NAME \
#    --role=$ROLE \
#    --group=$TEAM_EMAIL



EMAIL=fleet-team2-admin@meillier.altostrat.com
ROLE=admin
SCOPE_NAME=team-2
BINDING_NAME=team2-user1-scoperbac

gcloud container fleet scopes rbacrolebindings create $BINDING_NAME \
   --project $PROJECT_ID_FLEET \
   --scope=$SCOPE_NAME \
   --role=$ROLE \
   --user=$EMAIL



EMAIL=fleet-team3-admin@meillier.altostrat.com
ROLE=admin
SCOPE_NAME=team-3
BINDING_NAME=team3-user1-scoperbac

gcloud container fleet scopes rbacrolebindings create $BINDING_NAME \
   --project $PROJECT_ID_FLEET \
   --scope=$SCOPE_NAME \
   --role=$ROLE \
   --user=$EMAIL



### But user have no project access once logged into the console.
























# Grant cluster access to user (for other users than the admin user we used to deploy everything)
# https://docs.cloud.google.com/kubernetes-engine/enterprise/multicluster-management/gateway/setup#grant_iam_roles_to_users

# 1/ Gateway Roles
GATEWAY_ROLE=roles/gkehub.gatewayAdmin
    # - roles/gkehub.gatewayAdmin (imp: This role includes the gkehub.gateway.stream permission, which lets users run the the attach, cp, and exec kubectl commands)
    # or
    # - roles/gkehub.gatewayReader
    # or
    # - roles/gkehub.gatewayEditor

# 2/ roles/gkehub.viewer: This role lets a user retrieve cluster kubeconfigs


MEMBER=user:fleet-team1-admin@meillier.altostrat.com
gcloud projects add-iam-policy-binding $PROJECT_ID_FLEET \
    --member=$MEMBER \
    --role=$GATEWAY_ROLE

MEMBER=user:fleet-team2-admin@meillier.altostrat.com
gcloud projects add-iam-policy-binding $PROJECT_ID_FLEET \
    --member=$MEMBER \
    --role=$GATEWAY_ROLE


MEMBER=user:fleet-team3-admin@meillier.altostrat.com
gcloud projects add-iam-policy-binding $PROJECT_ID_FLEET \
    --member=$MEMBER \
    --role=$GATEWAY_ROLE

## Permission to get credentials on cluster denied so far
#  gcloud container fleet memberships get-credentials fleet-gke01 --project project-05713-fleet
# ERROR: (gcloud.container.fleet.memberships.get-credentials) PERMISSION_DENIED: Permission 'gkehub.memberships.list' denied on 'projects/project-05713-fleet/locations/-/memberships'. This command is authenticated as fleet-team3-admin@meillier.altostrat.com which is the active account specified by the [core/account] property

## Still no project access in console.




MEMBER=user:fleet-team1-admin@meillier.altostrat.com
gcloud projects add-iam-policy-binding $PROJECT_ID_FLEET \
    --member=$MEMBER \
    --role="roles/gkehub.viewer"

MEMBER=user:fleet-team2-admin@meillier.altostrat.com
gcloud projects add-iam-policy-binding $PROJECT_ID_FLEET \
    --member=$MEMBER \
    --role="roles/gkehub.viewer"

MEMBER=user:fleet-team3-admin@meillier.altostrat.com
gcloud projects add-iam-policy-binding $PROJECT_ID_FLEET \
    --member=$MEMBER \
    --role="roles/gkehub.viewer"

## Now can select fleet project in drop down
#### GKE > Fleet Team: 
        #Can see all teams, 
        #can browse other teams NS, 
        #clusters memberships... 
#### GKE > Clusters - no permissions



# gcloud projects get-ancestors-iam-policy $PROJECT_ID_FLEET \
# --flatten="policy.bindings[].members" \
# --filter="policy.bindings.members:$MEMBER" \
# --format="table[box](policy.bindings.role,policy.bindings.members,id,type)"
# 
# gcloud projects get-iam-policy $PROJECT_ID_FLEET \
# --flatten="bindings[].members" \
# --filter="members:$MEMBER" \
# --format="table[box](role, members)"





# For console access: https://docs.cloud.google.com/kubernetes-engine/enterprise/multicluster-management/gateway/setup#grant_roles_for_access_through_the_cloud_console
    #- roles/container.viewer 
    #- roles/gkehub.viewer - already from above








MEMBER=user:fleet-team1-admin@meillier.altostrat.com
gcloud projects add-iam-policy-binding $PROJECT_ID_FLEET \
    --member=$MEMBER \
    --role=roles/container.viewer

MEMBER=user:fleet-team2-admin@meillier.altostrat.com
gcloud projects add-iam-policy-binding $PROJECT_ID_FLEET \
    --member=$MEMBER \
    --role=roles/container.viewer

MEMBER=user:fleet-team3-admin@meillier.altostrat.com
gcloud projects add-iam-policy-binding $PROJECT_ID_FLEET \
    --member=$MEMBER \
    --role=roles/container.viewer

## User can see cluster in GKE > Clusters
## Cannot click on cluster to view details - cluster is on another project though.


# Additionally: nto in documentation 

ROLE=roles/container.clusterViewer

MEMBER=user:fleet-team1-admin@meillier.altostrat.com
# gcloud projects add-iam-policy-binding $PROJECT_ID_FLEET \
#     --member=$MEMBER \
#     --role=$ROLE
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=$MEMBER \
    --role=$ROLE


MEMBER=user:fleet-team2-admin@meillier.altostrat.com
# gcloud projects add-iam-policy-binding $PROJECT_ID_FLEET \
#     --member=$MEMBER \
#     --role=$ROLE
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=$MEMBER \
    --role=$ROLE

MEMBER=user:fleet-team3-admin@meillier.altostrat.com
# gcloud projects add-iam-policy-binding $PROJECT_ID_FLEET \
#     --member=$MEMBER \
#     --role=$ROLE
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=$MEMBER \
    --role=$ROLE















# At this point user can use gateway to get-credential on fleet cluster.
    # fleet_team1_admin@cloudshell:~ (project-05713-fleet)$ gcloud container fleet memberships get-credentials fleet-gke01
    # Fetching Gateway kubeconfig...
    # A new kubeconfig entry "connectgateway_project-05713-fleet_us-central1_fleet-gke01" has been generated and set as the current context.


# However the do not have cluster roles on the cluster itself so kubectl commands will fail
    # fleet_team1_admin@cloudshell:~ (project-05713-fleet)$ kubectl get nodes
    # Error from server (Forbidden): nodes is forbidden: User "fleet-team1-admin@meillier.altostrat.com" cannot list resource "nodes" in API group "" at the cluster scope: requires one of ["container.nodes.list"] permission(s).

# in the console, in the fleet team view, we see our user but it says that need Scope-level IAM acces, PRoject-level access, and Log IAM level access. 
    # Scope-level IAM Details: Missing permissions. For IAM roles ask the project owner to grant you permissions on the team scope (gkehub.scopes.getIamPolicy).
    # Project-level-IAM details: issing permissions. For IAM roles ask the project owner to grant you permissions on the project (resourcemanager.projects.getIamPolicy).
    # Log IAM Details: Missing permissions. For IAM roles ask the project owner to grant you permissions on the project (resourcemanager.projects.getIamPolicy).


# Generate and apply REquired RBAC Policies
# Again as our admin user we create and provide rbac access to our tenant admin users.
# https://docs.cloud.google.com/kubernetes-engine/enterprise/multicluster-management/gateway/setup#create_and_apply_required_rbac_policies

    # gcloud cli guide : https://docs.cloud.google.com/sdk/gcloud/reference/container/fleet/memberships/generate-gateway-rbac


#Cluster roles can be: 
    #clusterrole/cluster-admin, 
    #clusterrole/cloud-console-reader,
    #role/mynamespace/namespace-reader
    #custom


#gcloud container fleet memberships list --project $PROJECT_ID_FLEET


USERS="fleet-team1-admin@meillier.altostrat.com"
ROLE="clusterrole/cluster-admin"

gcloud container fleet memberships get-credentials fleet-gke01 --project $PROJECT_ID_FLEET
MEMBERSHIP_NAME="fleet-gke01"
KUBECONFIG_CONTEXT="connectgateway_project-05713-fleet_us-central1_fleet-gke01"
    # as admin user (iser who created gke cluster) do a gcloud container clusters get-credentials and then get the context. 
    # gcloud container clusters get-credentials gke01 --location us-central1
    # kubectl config current-context
gcloud container fleet memberships generate-gateway-rbac  \
    --membership=$MEMBERSHIP_NAME \
    --role=$ROLE \
    --users=$USERS \
    --project=$PROJECT_ID_FLEET \
    --kubeconfig="~/.kube/config" \
    --context=$KUBECONFIG_CONTEXT \
    --apply

gcloud container fleet memberships get-credentials fleet-gke02 --project $PROJECT_ID_FLEET
MEMBERSHIP_NAME="fleet-gke02"
KUBECONFIG_CONTEXT="connectgateway_project-05713-fleet_us-central1_fleet-gke02"
gcloud container fleet memberships generate-gateway-rbac  \
    --membership=$MEMBERSHIP_NAME \
    --role=$ROLE \
    --users=$USERS \
    --project=$PROJECT_ID_FLEET \
    --kubeconfig="~/.kube/config" \
    --context=$KUBECONFIG_CONTEXT \
    --apply




USERS="fleet-team2-admin@meillier.altostrat.com"
ROLE="clusterrole/cluster-admin"

gcloud container fleet memberships get-credentials fleet-gke02 --project $PROJECT_ID_FLEET
MEMBERSHIP_NAME="fleet-gke02"
KUBECONFIG_CONTEXT="connectgateway_project-05713-fleet_us-central1_fleet-gke02"
gcloud container fleet memberships generate-gateway-rbac  \
    --membership=$MEMBERSHIP_NAME \
    --role=$ROLE \
    --users=$USERS \
    --project=$PROJECT_ID_FLEET \
    --kubeconfig="~/.kube/config" \
    --context=$KUBECONFIG_CONTEXT \
    --apply

gcloud container fleet memberships get-credentials fleet-gke03 --project $PROJECT_ID_FLEET
MEMBERSHIP_NAME="fleet-gke03"
KUBECONFIG_CONTEXT="connectgateway_project-05713-fleet_us-central1_fleet-gke03"
gcloud container fleet memberships generate-gateway-rbac  \
    --membership=$MEMBERSHIP_NAME \
    --role=$ROLE \
    --users=$USERS \
    --project=$PROJECT_ID_FLEET \
    --kubeconfig="~/.kube/config" \
    --context=$KUBECONFIG_CONTEXT \
    --apply







USERS="fleet-team3-admin@meillier.altostrat.com"
ROLE="clusterrole/cluster-admin"



gcloud container fleet memberships get-credentials fleet-gke01 --project $PROJECT_ID_FLEET
MEMBERSHIP_NAME="fleet-gke01"
KUBECONFIG_CONTEXT="connectgateway_project-05713-fleet_us-central1_fleet-gke01"
gcloud container fleet memberships generate-gateway-rbac  \
    --membership=$MEMBERSHIP_NAME \
    --role=$ROLE \
    --users=$USERS \
    --project=$PROJECT_ID_FLEET \
    --kubeconfig="~/.kube/config" \
    --context=$KUBECONFIG_CONTEXT \
    --apply

gcloud container fleet memberships get-credentials fleet-gke02 --project $PROJECT_ID_FLEET
MEMBERSHIP_NAME="fleet-gke02"
KUBECONFIG_CONTEXT="connectgateway_project-05713-fleet_us-central1_fleet-gke02"
gcloud container fleet memberships generate-gateway-rbac  \
    --membership=$MEMBERSHIP_NAME \
    --role=$ROLE \
    --users=$USERS \
    --project=$PROJECT_ID_FLEET \
    --kubeconfig="~/.kube/config" \
    --context=$KUBECONFIG_CONTEXT \
    --apply

gcloud container fleet memberships get-credentials fleet-gke03 --project $PROJECT_ID_FLEET
MEMBERSHIP_NAME="fleet-gke03"
KUBECONFIG_CONTEXT="connectgateway_project-05713-fleet_us-central1_fleet-gke03"
gcloud container fleet memberships generate-gateway-rbac  \
    --membership=$MEMBERSHIP_NAME \
    --role=$ROLE \
    --users=$USERS \
    --project=$PROJECT_ID_FLEET \
    --kubeconfig="~/.kube/config" \
    --context=$KUBECONFIG_CONTEXT \
    --apply
































## Now user1 can see the nodes from gke01. but not gke02
    # anthos_tenant1@cloudshell:~ (project-05713-fleet)$ gcloud container fleet memberships get-credentials gke02
    # Fetching Gateway kubeconfig...
    # A new kubeconfig entry "connectgateway_project-05713-fleet_us-central1_gke02" has been generated and set as the current context.

    # anthos_tenant1@cloudshell:~ (project-05713-fleet)$ kubectl config current-context
    # connectgateway_project-05713-fleet_us-central1_gke02

    # anthos_tenant1@cloudshell:~ (project-05713-fleet)$ kubectl get nodes
    # Error from server (Forbidden): nodes is forbidden: User "anthos-tenant1@meillier.altostrat.com" cannot list resource "nodes" in API group "" at the cluster scope: requires one of ["container.nodes.list"] permission(s).

    # anthos_tenant1@cloudshell:~ (project-05713-fleet)$ gcloud container fleet memberships get-credentials gke01
    # Fetching Gateway kubeconfig...
    # A new kubeconfig entry "connectgateway_project-05713-fleet_us-central1_gke01" has been generated and set as the current context.

    # anthos_tenant1@cloudshell:~ (project-05713-fleet)$ kubectl config current-context
    # connectgateway_project-05713-fleet_us-central1_gke01

    # anthos_tenant1@cloudshell:~ (project-05713-fleet)$ kubectl get nodes
    # NAME                                    STATUS   ROLES    AGE   VERSION
    # gke-gke01-pool-system-97593285-qvl2     Ready    <none>   24h   v1.34.3-gke.1245000
    # gke-gke01-pool-system-97593285-rmpj     Ready    <none>   24h   v1.34.3-gke.1245000
    # gke-gke01-pool-system-97593285-wd6l     Ready    <none>   24h   v1.34.3-gke.1245000
    # gke-gke01-pool-wrkld-01-1edf975d-5nj4   Ready    <none>   24h   v1.34.3-gke.1245000
    # anthos_tenant1@cloudshell:~ (project-05713-fleet)$


# Workloads access to service in fleet project (if any):
# For cross-project fleet registration, your custom service account ($GKE_NODE_SA_EMAIL) typically stays within its home project's IAM scope for node-level operations. However, the Fleet Service Agent from your host project requires specific cross-project permissions to "reach into" your cluster's project and manage the membership.
# Workloads Cross-Project GCP SERvices access: If your workloads need to access resources (like a storage bucket) in the Fleet Host Project, you must manually grant your service account the necessary roles in that specific project.