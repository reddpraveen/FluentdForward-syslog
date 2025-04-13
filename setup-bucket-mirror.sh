#!/bin/bash

set -e

echo "Setting up bucket mirror job in OpenShift..."

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

# Step 1: Verify source bucket secret exists (NooBaa MCG)
echo "Step 1: Verifying source bucket secret (NooBaa MCG)..."
if ! oc get secret logging-loki-odf -n openshift-logging &> /dev/null; then
    echo "Error: Source bucket secret 'logging-loki-odf' not found in openshift-logging namespace."
    echo "Please ensure the NooBaa MCG bucket secret exists."
    exit 1
fi

# Step 2: Verify target bucket secret exists (RGW)
echo "Step 2: Verifying target bucket secret (RGW)..."
if ! oc get secret logging-loki-rgw -n openshift-logging &> /dev/null; then
    echo "Error: Target bucket secret 'logging-loki-rgw' not found in openshift-logging namespace."
    echo "Please ensure the RGW bucket secret exists."
    exit 1
fi

# Step 3: Create kubeconfig secret for the job to interact with OpenShift
echo "Step 3: Creating kubeconfig secret..."
# Get the current kubeconfig
KUBECONFIG_CONTENT=$(cat $KUBECONFIG || cat ~/.kube/config)

# Create the kubeconfig secret
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: bucket-mirror-kubeconfig
  namespace: openshift-logging
type: Opaque
stringData:
  config: |
$(echo "$KUBECONFIG_CONTENT" | sed 's/^/    /')
EOF

# Step 4: Apply the job
echo "Step 4: Applying the bucket mirror job..."
oc apply -f loki-bucket-mirror-job.yaml

# Step 5: Monitor the job
echo "Step 5: Monitoring the job..."
echo "You can check the progress with: oc logs -f job/loki-bucket-mirror -n openshift-logging"

# Wait for job completion
while true; do
    STATUS=$(oc get job loki-bucket-mirror -n openshift-logging -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}')
    if [ "$STATUS" == "True" ]; then
        echo "Mirror job completed successfully"
        break
    fi
    FAILED=$(oc get job loki-bucket-mirror -n openshift-logging -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}')
    if [ "$FAILED" == "True" ]; then
        echo "Mirror job failed. Check logs for details"
        oc logs job/loki-bucket-mirror -n openshift-logging
        exit 1
    fi
    sleep 30
done

echo "Bucket mirror process completed successfully."
echo "If you need to rollback, use:"
echo "oc patch lokistack instance -n openshift-logging --type=merge -p '{\"spec\":{\"storage\":{\"secret\":{\"name\":\"logging-loki-odf\"}}}}'" 