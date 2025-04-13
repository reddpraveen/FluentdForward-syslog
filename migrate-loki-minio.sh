#!/bin/bash

set -e

echo "Starting Loki bucket migration process using MinIO..."

# Step 1: Create MinIO bucket for Loki
echo "Step 1: Creating MinIO bucket for Loki..."
cat <<EOF | oc apply -f -
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: loki-minio-bucket
  namespace: openshift-logging
spec:
  generateBucketName: loki-minio
  storageClassName: ocs-storagecluster-ceph-rgw
EOF

# Step 2: Wait for bucket creation
echo "Step 2: Waiting for bucket creation..."
sleep 30

# Step 3: Start the migration job
echo "Step 3: Starting data migration job..."
oc apply -f loki-migration-job-minio.yaml

# Step 4: Monitor the migration progress
echo "Step 4: Monitoring migration progress..."
echo "You can check the progress with: oc logs -f job/loki-bucket-migration-minio -n openshift-logging"

# Wait for job completion
while true; do
    STATUS=$(oc get job loki-bucket-migration-minio -n openshift-logging -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}')
    if [ "$STATUS" == "True" ]; then
        echo "Migration job completed successfully"
        break
    fi
    FAILED=$(oc get job loki-bucket-migration-minio -n openshift-logging -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}')
    if [ "$FAILED" == "True" ]; then
        echo "Migration job failed. Check logs for details"
        exit 1
    fi
    sleep 30
done

# Step 5: Verify the migration
echo "Step 5: Verifying migration..."
echo "Checking if data is accessible in the target bucket..."

# Create a temporary pod to verify data
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: loki-verify-minio
  namespace: openshift-logging
spec:
  containers:
  - name: loki-verify
    image: registry.redhat.io/openshift-logging/loki-rhel9:latest
    command: ["/bin/sh", "-c"]
    args:
    - |
      # Extract credentials
      export TARGET_ACCESS_KEY=$(cat /secrets/target/AWS_ACCESS_KEY_ID)
      export TARGET_SECRET_KEY=$(cat /secrets/target/AWS_SECRET_ACCESS_KEY)
      export TARGET_BUCKET=$(cat /secrets/target/bucket)
      
      # Create Loki config
      cat > /tmp/loki-config.yaml << EOF
      auth_enabled: false
      
      server:
        http_listen_port: 3100
      
      common:
        path_prefix: /tmp/loki
        storage:
          filesystem:
            chunks_directory: /tmp/loki/chunks
            rules_directory: /tmp/loki/rules
        replication_factor: 1
        ring:
          kvstore:
            store: inmemory
      
      schema_config:
        configs:
          - from: 2020-10-24
            store: boltdb-shipper
            object_store: s3
            schema: v11
            index:
              prefix: index_
              period: 24h
      
      storage_config:
        boltdb_shipper:
          active_index_directory: /tmp/loki/boltdb-shipper-active
          cache_location: /tmp/loki/boltdb-shipper-cache
          cache_ttl: 24h
          shared_store: s3
        aws:
          s3: s3://\${TARGET_ACCESS_KEY}:\${TARGET_SECRET_KEY}@minio.openshift-storage.svc:9000/\${TARGET_BUCKET}
          insecure: true
          http_config:
            insecure_skip_verify: true
          # MinIO specific settings
          s3forcepathstyle: true
          bucketnames: \${TARGET_BUCKET}
      
      compactor:
        working_directory: /tmp/loki/compactor
        shared_store: s3
        compaction_interval: 5m
        retention_enabled: true
        retention_delete_delay: 2h
        retention_delete_worker_count: 150
        retention_period: 744h
      
      limits_config:
        retention_period: 744h
      EOF
      
      # Start Loki
      mkdir -p /tmp/loki/chunks /tmp/loki/rules /tmp/loki/boltdb-shipper-active /tmp/loki/boltdb-shipper-cache /tmp/loki/compactor
      loki -config.file=/tmp/loki-config.yaml &
      
      # Wait for Loki to start
      sleep 30
      
      # Check if data is accessible
      TENANTS=\$(curl -s http://localhost:3100/loki/api/v1/tenants)
      if [ -z "\$TENANTS" ]; then
        echo "No tenants found in target bucket"
        exit 1
      fi
      
      echo "Found tenants: \$TENANTS"
      
      # Check if we can query data
      for TENANT in \$TENANTS; do
        echo "Checking tenant: \$TENANT"
        RESULT=\$(curl -s "http://localhost:3100/loki/api/v1/query_range" \
          -H "X-Scope-OrgID: \$TENANT" \
          -G --data-urlencode "query={}" \
          --data-urlencode "start=0" \
          --data-urlencode "end=\$(date +%s)000" \
          --data-urlencode "limit=10")
        
        if [ "\$(echo \$RESULT | jq '.data.result | length')" -gt 0 ]; then
          echo "Data is accessible for tenant \$TENANT"
        else
          echo "No data found for tenant \$TENANT"
          exit 1
        fi
      done
      
      echo "Verification successful"
  volumes:
  - name: target-secret
    secret:
      secretName: loki-minio-bucket
  restartPolicy: Never
EOF

# Wait for verification pod to complete
while true; do
    STATUS=$(oc get pod loki-verify-minio -n openshift-logging -o jsonpath='{.status.phase}')
    if [ "$STATUS" == "Succeeded" ]; then
        echo "Verification successful"
        break
    fi
    if [ "$STATUS" == "Failed" ]; then
        echo "Verification failed. Check logs for details"
        oc logs loki-verify-minio -n openshift-logging
        oc delete pod loki-verify-minio -n openshift-logging
        exit 1
    fi
    sleep 10
done

# Clean up verification pod
oc delete pod loki-verify-minio -n openshift-logging

# Step 6: Update LokiStack configuration
echo "Step 6: Updating LokiStack configuration..."
oc patch lokistack instance -n openshift-logging --type=merge -p '{
  "spec": {
    "storage": {
      "secret": {
        "name": "loki-minio-bucket"
      }
    }
  }
}'

# Step 7: Restart Loki pods
echo "Step 7: Restarting Loki pods..."
oc rollout restart deployment -l app.kubernetes.io/name=loki -n openshift-logging

echo "Migration process completed successfully"
echo "Please verify Loki functionality in the OpenShift UI"
echo "If issues occur, you can rollback using:"
echo "oc patch lokistack instance -n openshift-logging --type=merge -p '{\"spec\":{\"storage\":{\"secret\":{\"name\":\"logging-loki-odf\"}}}}'" 