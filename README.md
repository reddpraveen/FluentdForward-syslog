# Loki Data Migration for OpenShift

This repository contains scripts and configurations for migrating Loki data in OpenShift from one storage backend to another. Two migration approaches are provided:

1. **RGW (Ceph Object Gateway) Migration** - Migrates data to a new RGW bucket
2. **MinIO Migration** - Migrates data to a MinIO bucket

## Prerequisites

- OpenShift cluster with LokiStack installed
- Access to the OpenShift cluster with `oc` command-line tool
- Sufficient permissions to create resources in the `openshift-logging` namespace
- `jq` command-line tool installed (for JSON processing)

## Migration Approaches

### 1. RGW (Ceph Object Gateway) Migration

This approach migrates Loki data to a new RGW bucket using the Ceph Object Gateway.

**Files:**
- `migrate-loki.sh` - Main script for RGW migration
- `loki-migration-job.yaml` - Kubernetes job for data migration

**Steps:**
1. Creates a new RGW bucket for Loki
2. Runs a migration job to copy data from the source bucket to the target bucket
3. Verifies the migration by checking data accessibility
4. Updates the LokiStack configuration to use the new bucket
5. Restarts Loki pods to apply the changes

**Usage:**
```bash
chmod +x migrate-loki.sh
./migrate-loki.sh
```

### 2. MinIO Migration

This approach migrates Loki data to a MinIO bucket.

**Files:**
- `migrate-loki-minio.sh` - Main script for MinIO migration
- `loki-migration-job-minio.yaml` - Kubernetes job for data migration

**Steps:**
1. Creates a new MinIO bucket for Loki
2. Runs a migration job to copy data from the source bucket to the MinIO bucket
3. Verifies the migration by checking data accessibility
4. Updates the LokiStack configuration to use the new bucket
5. Restarts Loki pods to apply the changes

**Usage:**
```bash
chmod +x migrate-loki-minio.sh
./migrate-loki-minio.sh
```

## How It Works

Both migration approaches follow a similar process:

1. **Bucket Creation**: Creates a new bucket in the target storage system
2. **Data Migration**: Uses a Kubernetes job to:
   - Start a source Loki instance connected to the original bucket
   - Start a target Loki instance connected to the new bucket
   - Query data from the source and push it to the target
3. **Verification**: Creates a temporary pod to verify data accessibility in the new bucket
4. **Configuration Update**: Updates the LokiStack to use the new bucket
5. **Pod Restart**: Restarts Loki pods to apply the changes

## Rollback

If issues occur during or after migration, you can rollback to the original configuration:

```bash
oc patch lokistack instance -n openshift-logging --type=merge -p '{"spec":{"storage":{"secret":{"name":"logging-loki-odf"}}}}'
```

## Troubleshooting

- Check the migration job logs: `oc logs -f job/loki-bucket-migration -n openshift-logging`
- Check the verification pod logs: `oc logs loki-verify -n openshift-logging`
- Ensure the bucket secrets are correctly mounted
- Verify network connectivity between Loki and the storage backends

## Notes

- The migration process preserves all tenants and their data
- The migration job uses Red Hat's official Loki image for OpenShift
- Both approaches use the same data migration logic but with different storage backends
- The MinIO approach includes specific settings for MinIO compatibility 