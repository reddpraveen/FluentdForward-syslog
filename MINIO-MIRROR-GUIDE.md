# MinIO Mirror Guide for Loki Data

This guide explains how to use the MinIO client (`mc`) to mirror Loki data from an OpenShift S3 bucket to a MinIO bucket, preserving all metadata and structure.

## Prerequisites

- Access to your OpenShift cluster with `oc` command-line tool
- MinIO client (`mc`) installed on your build server
- Access to the MinIO server where you want to mirror the data
- Sufficient permissions to read from the source bucket and write to the target bucket

## Installing MinIO Client

If you don't have the MinIO client installed, you can install it using one of these methods:

### On Linux:

```bash
# For Debian/Ubuntu
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# For RHEL/CentOS
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/
```

### On macOS:

```bash
brew install minio/stable/mc
```

## Understanding Loki's Storage Structure

Loki uses a specific storage structure in S3-compatible storage:

1. **Index Files**: Named with the prefix `index_` followed by a timestamp
2. **Chunk Files**: Stored in the `chunks/` directory
3. **Tenant-specific Data**: Organized by tenant ID
4. **Metadata**: Includes information about data retention, compaction, etc.

When mirroring, it's crucial to preserve this structure to ensure Loki can read the data correctly.

## Step-by-Step Mirroring Process

### 1. Get Source Bucket Credentials

Extract the credentials from the OpenShift secret:

```bash
SOURCE_ACCESS_KEY=$(oc get secret logging-loki-odf -n openshift-logging -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
SOURCE_SECRET_KEY=$(oc get secret logging-loki-odf -n openshift-logging -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)
SOURCE_BUCKET=$(oc get secret logging-loki-odf -n openshift-logging -o jsonpath='{.data.bucket}' | base64 -d)
```

### 2. Configure MinIO Client

Set up aliases for both source and target:

```bash
# For source (OpenShift S3)
mc alias set source "https://s3.openshift-storage.svc:443" "$SOURCE_ACCESS_KEY" "$SOURCE_SECRET_KEY" --insecure

# For target (MinIO)
mc alias set target "http://your-minio-server:9000" "your-access-key" "your-secret-key" --insecure
```

### 3. Create Target Bucket

Create the target bucket if it doesn't exist:

```bash
mc mb target/your-target-bucket || true
```

### 4. Mirror Objects

Use the `mirror` command with the `--preserve` flag to maintain metadata:

```bash
mc mirror --preserve source/$SOURCE_BUCKET target/your-target-bucket
```

The `--preserve` flag ensures that all metadata (including content-type, user metadata, etc.) is preserved during the mirroring process.

### 5. Verify the Mirroring

Check that all objects have been mirrored correctly:

```bash
# Count objects in source and target
SOURCE_COUNT=$(mc ls source/$SOURCE_BUCKET | wc -l)
TARGET_COUNT=$(mc ls target/your-target-bucket | wc -l)

echo "Source bucket object count: $SOURCE_COUNT"
echo "Target bucket object count: $TARGET_COUNT"
```

### 6. Check Loki-specific Metadata

Verify that Loki-specific files are present:

```bash
# Check for index files
INDEX_COUNT=$(mc ls source/$SOURCE_BUCKET | grep -c "index_" || true)
echo "Found $INDEX_COUNT index files in source bucket"

# Check for chunk files
CHUNK_COUNT=$(mc ls source/$SOURCE_BUCKET | grep -c "chunks/" || true)
echo "Found $CHUNK_COUNT chunk files in source bucket"
```

## Updating LokiStack Configuration

After mirroring, you may want to update the LokiStack to use the new bucket:

1. Create a secret for the new bucket:

```bash
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: loki-minio-bucket
  namespace: openshift-logging
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: your-minio-access-key
  AWS_SECRET_ACCESS_KEY: your-minio-secret-key
  bucket: your-target-bucket
EOF
```

2. Update the LokiStack configuration:

```bash
oc patch lokistack instance -n openshift-logging --type=merge -p '{
  "spec": {
    "storage": {
      "secret": {
        "name": "loki-minio-bucket"
      }
    }
  }
}'
```

3. Restart Loki pods:

```bash
oc rollout restart deployment -l app.kubernetes.io/name=loki -n openshift-logging
```

## Troubleshooting

### Object Count Mismatch

If the object counts don't match, check for any errors during the mirroring process:

```bash
mc mirror --preserve --debug source/$SOURCE_BUCKET target/your-target-bucket
```

### Missing Loki Files

If Loki-specific files are missing, you may need to manually copy them:

```bash
# Copy index files
mc cp --recursive source/$SOURCE_BUCKET/index_* target/your-target-bucket/

# Copy chunk files
mc cp --recursive source/$SOURCE_BUCKET/chunks/ target/your-target-bucket/
```

### Rollback

If you encounter issues after updating the LokiStack, you can rollback to the original configuration:

```bash
oc patch lokistack instance -n openshift-logging --type=merge -p '{"spec":{"storage":{"secret":{"name":"logging-loki-odf"}}}}'
```

## Advanced Options

### Incremental Mirroring

For large buckets, you might want to use incremental mirroring:

```bash
mc mirror --preserve --newer source/$SOURCE_BUCKET target/your-target-bucket
```

### Exclude Patterns

If you want to exclude certain files or patterns:

```bash
mc mirror --preserve --exclude "*.tmp" source/$SOURCE_BUCKET target/your-target-bucket
```

### Bandwidth Limiting

To limit bandwidth usage:

```bash
mc mirror --preserve --bandwidth 10MiB source/$SOURCE_BUCKET target/your-target-bucket
```

## Conclusion

Using the MinIO client to mirror Loki data is a straightforward process that preserves all metadata and structure. This approach is particularly useful when you want to migrate data without running a Kubernetes job or when you need more control over the mirroring process. 