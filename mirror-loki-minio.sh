#!/bin/bash

set -e

echo "Starting Loki bucket mirroring process using MinIO client..."

# Check if MinIO client is installed
if ! command -v mc &> /dev/null; then
    echo "MinIO client (mc) is not installed. Installing..."
    
    # Detect OS and install MinIO client
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v apt-get &> /dev/null; then
            # Debian/Ubuntu
            wget https://dl.min.io/client/mc/release/linux-amd64/mc
            chmod +x mc
            sudo mv mc /usr/local/bin/
        elif command -v yum &> /dev/null; then
            # RHEL/CentOS
            wget https://dl.min.io/client/mc/release/linux-amd64/mc
            chmod +x mc
            sudo mv mc /usr/local/bin/
        else
            echo "Unsupported Linux distribution. Please install MinIO client manually."
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        brew install minio/stable/mc
    else
        echo "Unsupported operating system. Please install MinIO client manually."
        exit 1
    fi
fi

# Step 1: Get source bucket credentials from OpenShift
echo "Step 1: Getting source bucket credentials from OpenShift..."
SOURCE_ACCESS_KEY=$(oc get secret logging-loki-odf -n openshift-logging -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
SOURCE_SECRET_KEY=$(oc get secret logging-loki-odf -n openshift-logging -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)
SOURCE_BUCKET=$(oc get secret logging-loki-odf -n openshift-logging -o jsonpath='{.data.bucket}' | base64 -d)

# Step 2: Get or create MinIO credentials
echo "Step 2: Setting up MinIO credentials..."
read -p "Enter MinIO server URL (e.g., http://minio.example.com:9000): " MINIO_ENDPOINT
read -p "Enter MinIO access key: " MINIO_ACCESS_KEY
read -p "Enter MinIO secret key: " MINIO_SECRET_KEY
read -p "Enter target bucket name: " TARGET_BUCKET

# Step 3: Configure MinIO client
echo "Step 3: Configuring MinIO client..."
mc alias set source "https://s3.openshift-storage.svc:443" "$SOURCE_ACCESS_KEY" "$SOURCE_SECRET_KEY" --insecure
mc alias set target "$MINIO_ENDPOINT" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" --insecure

# Step 4: Create target bucket if it doesn't exist
echo "Step 4: Creating target bucket if it doesn't exist..."
mc mb target/$TARGET_BUCKET || true

# Step 5: Mirror objects from source to target
echo "Step 5: Mirroring objects from source to target..."
echo "This may take a while depending on the amount of data..."

# Mirror all objects with metadata
mc mirror --preserve source/$SOURCE_BUCKET target/$TARGET_BUCKET

# Step 6: Verify the mirroring
echo "Step 6: Verifying the mirroring..."
SOURCE_COUNT=$(mc ls source/$SOURCE_BUCKET | wc -l)
TARGET_COUNT=$(mc ls target/$TARGET_BUCKET | wc -l)

echo "Source bucket object count: $SOURCE_COUNT"
echo "Target bucket object count: $TARGET_COUNT"

if [ "$SOURCE_COUNT" -eq "$TARGET_COUNT" ]; then
    echo "Mirroring completed successfully. Object counts match."
else
    echo "Warning: Object counts don't match. Some objects may not have been mirrored."
    echo "Source count: $SOURCE_COUNT, Target count: $TARGET_COUNT"
fi

# Step 7: Check for Loki-specific metadata
echo "Step 7: Checking for Loki-specific metadata..."
echo "Checking for index files..."
INDEX_COUNT=$(mc ls source/$SOURCE_BUCKET | grep -c "index_" || true)
echo "Found $INDEX_COUNT index files in source bucket"

echo "Checking for chunk files..."
CHUNK_COUNT=$(mc ls source/$SOURCE_BUCKET | grep -c "chunks/" || true)
echo "Found $CHUNK_COUNT chunk files in source bucket"

# Step 8: Update LokiStack configuration (optional)
read -p "Do you want to update the LokiStack configuration to use the new bucket? (y/n): " UPDATE_CONFIG
if [[ "$UPDATE_CONFIG" == "y" || "$UPDATE_CONFIG" == "Y" ]]; then
    echo "Updating LokiStack configuration..."
    
    # Create a secret for the new bucket
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: loki-minio-bucket
  namespace: openshift-logging
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: $MINIO_ACCESS_KEY
  AWS_SECRET_ACCESS_KEY: $MINIO_SECRET_KEY
  bucket: $TARGET_BUCKET
EOF
    
    # Update LokiStack configuration
    oc patch lokistack instance -n openshift-logging --type=merge -p "{
      \"spec\": {
        \"storage\": {
          \"secret\": {
            \"name\": \"loki-minio-bucket\"
          }
        }
      }
    }"
    
    # Restart Loki pods
    echo "Restarting Loki pods..."
    oc rollout restart deployment -l app.kubernetes.io/name=loki -n openshift-logging
fi

echo "Mirroring process completed."
echo "If you need to rollback, use:"
echo "oc patch lokistack instance -n openshift-logging --type=merge -p '{\"spec\":{\"storage\":{\"secret\":{\"name\":\"logging-loki-odf\"}}}}'" 