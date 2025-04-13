#!/bin/bash

set -e

# Step 1: Verify current Loki configuration
echo "Step 1: Verifying current Loki configuration..."
CURRENT_BUCKET=$(oc get secret logging-loki-odf -n openshift-logging -o jsonpath='{.data.bucket}' | base64 -d)
echo "Current Loki bucket: $CURRENT_BUCKET"

# Step 2: Create new RGW bucket for Loki
echo "Step 2: Creating new RGW bucket for Loki..."
cat <<EOF | oc apply -f -
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: loki-rgw-bucket
  namespace: openshift-logging
spec:
  generateBucketName: loki-rgw
  storageClassName: ocs-storagecluster-ceph-rgw
EOF

# Step 3: Wait for bucket creation
echo "Step 3: Waiting for bucket creation..."
sleep 30

# Step 4: Apply the mirror bucket class
echo "Step 4: Applying mirror bucket class..."
oc apply -f bucket-class.yaml

# Step 5: Wait for mirroring to complete
echo "Step 5: Waiting for initial mirroring to complete..."
echo "This may take several minutes depending on data size..."
sleep 300

# Step 6: Verify data and metadata replication
echo "Step 6: Verifying data and metadata replication..."
SOURCE_ACCESS_KEY=$(oc get secret logging-loki-odf -n openshift-logging -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
SOURCE_SECRET_KEY=$(oc get secret logging-loki-odf -n openshift-logging -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)
DEST_ACCESS_KEY=$(oc get secret loki-rgw-bucket -n openshift-logging -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
DEST_SECRET_KEY=$(oc get secret loki-rgw-bucket -n openshift-logging -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)

# Verify object count and metadata
echo "Verifying object counts and metadata..."
SOURCE_COUNT=$(aws s3api list-objects-v2 --bucket $CURRENT_BUCKET --endpoint-url https://s3.openshift-storage.svc:443 --query 'Contents[].{Key:Key,Size:Size,LastModified:LastModified}' --output json)
DEST_COUNT=$(aws s3api list-objects-v2 --bucket loki-rgw --endpoint-url https://rgw.openshift-storage.svc:443 --query 'Contents[].{Key:Key,Size:Size,LastModified:LastModified}' --output json)

if [ "$SOURCE_COUNT" = "$DEST_COUNT" ]; then
    echo "Data and metadata replication verified successfully"
else
    echo "Warning: Data or metadata counts don't match. Please verify manually"
    echo "Source count: $SOURCE_COUNT"
    echo "Destination count: $DEST_COUNT"
fi

# Step 7: Update LokiStack configuration
echo "Step 7: Updating LokiStack configuration..."
oc patch lokistack instance -n openshift-logging --type=merge -p '{
  "spec": {
    "storage": {
      "secret": {
        "name": "loki-rgw-bucket"
      }
    }
  }
}'

# Step 8: Restart Loki pods
echo "Step 8: Restarting Loki pods..."
oc rollout restart deployment -l app.kubernetes.io/name=loki -n openshift-logging

echo "Migration process completed. Please verify Loki functionality."
echo "If issues occur, you can rollback by updating the LokiStack to use the original bucket." 