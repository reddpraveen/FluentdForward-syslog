#!/bin/bash

set -e

echo "Setting up MinIO mirror job in OpenShift..."

# Check if we're logged into OpenShift
if ! oc whoami &> /dev/null; then
    echo "Error: Not logged into OpenShift. Please run 'oc login' first."
    exit 1
fi

# Create namespace if it doesn't exist
if ! oc get namespace openshift-logging &> /dev/null; then
    echo "Creating openshift-logging namespace..."
    oc create namespace openshift-logging
fi

# Step 1: Create MinIO credentials secret
echo "Step 1: Creating MinIO credentials secret..."
read -p "Enter MinIO server URL (e.g., http://minio.example.com:9000): " MINIO_ENDPOINT
read -p "Enter MinIO access key: " MINIO_ACCESS_KEY
read -p "Enter MinIO secret key: " MINIO_SECRET_KEY
read -p "Enter target bucket name: " TARGET_BUCKET

# Create the MinIO credentials secret
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
  namespace: openshift-logging
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: $MINIO_ACCESS_KEY
  AWS_SECRET_ACCESS_KEY: $MINIO_SECRET_KEY
  bucket: $TARGET_BUCKET
  endpoint: $MINIO_ENDPOINT
EOF

# Step 2: Create kubeconfig secret for the job to interact with OpenShift
echo "Step 2: Creating kubeconfig secret..."
# Get the current kubeconfig
KUBECONFIG_CONTENT=$(cat $KUBECONFIG || cat ~/.kube/config)

# Create the kubeconfig secret
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: minio-mirror-kubeconfig
  namespace: openshift-logging
type: Opaque
stringData:
  config: |
$(echo "$KUBECONFIG_CONTENT" | sed 's/^/    /')
EOF

# Step 3: Apply the job
echo "Step 3: Applying the MinIO mirror job..."
oc apply -f loki-minio-mirror-job.yaml

# Step 4: Monitor the job
echo "Step 4: Monitoring the job..."
echo "You can check the progress with: oc logs -f job/loki-minio-mirror -n openshift-logging"

# Wait for job completion
while true; do
    STATUS=$(oc get job loki-minio-mirror -n openshift-logging -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}')
    if [ "$STATUS" == "True" ]; then
        echo "Mirror job completed successfully"
        break
    fi
    FAILED=$(oc get job loki-minio-mirror -n openshift-logging -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}')
    if [ "$FAILED" == "True" ]; then
        echo "Mirror job failed. Check logs for details"
        oc logs job/loki-minio-mirror -n openshift-logging
        exit 1
    fi
    sleep 30
done

echo "MinIO mirror process completed successfully."
echo "If you need to rollback, use:"
echo "oc patch lokistack instance -n openshift-logging --type=merge -p '{\"spec\":{\"storage\":{\"secret\":{\"name\":\"logging-loki-odf\"}}}}'" 