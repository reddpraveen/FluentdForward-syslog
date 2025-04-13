# MinIO Mirror Job for Loki Data in OpenShift

This repository contains scripts and configurations for mirroring Loki data in OpenShift from an S3 bucket to a MinIO bucket using a Kubernetes job with a Red Hat-based MinIO client image.

## Overview

This approach uses a Kubernetes job running in OpenShift to mirror Loki data from the source S3 bucket to a MinIO bucket. The job uses the MinIO client (`mc`) to perform the mirroring, preserving all metadata and structure.

## Prerequisites

- OpenShift cluster with LokiStack installed
- Access to the OpenShift cluster with `oc` command-line tool
- Sufficient permissions to create resources in the `openshift-logging` namespace
- MinIO server with access credentials

## Files

- `loki-minio-mirror-job.yaml` - Kubernetes job manifest for mirroring Loki data
- `setup-minio-mirror.sh` - Script to set up secrets and run the mirror job

## How It Works

The mirroring process follows these steps:

1. **Setup**: Create necessary secrets for MinIO credentials and kubeconfig
2. **Job Execution**: Run a Kubernetes job that:
   - Uses the MinIO client to connect to both source and target buckets
   - Mirrors all objects with metadata preservation
   - Verifies the mirroring by comparing object counts
   - Updates the LokiStack configuration to use the new bucket
3. **Verification**: Check that the mirroring was successful

## Usage

1. Make the setup script executable:
   ```bash
   chmod +x setup-minio-mirror.sh
   ```

2. Run the setup script:
   ```bash
   ./setup-minio-mirror.sh
   ```

3. Follow the prompts to enter your MinIO server details and credentials

4. The script will:
   - Create the necessary secrets
   - Apply the mirror job
   - Monitor the job progress
   - Report the results

## Advantages of This Approach

1. **Red Hat Compatibility**: Uses Red Hat's official MinIO client image
2. **OpenShift Integration**: Runs directly within your OpenShift cluster
3. **Automation**: Automates the entire mirroring process
4. **Verification**: Includes steps to verify the mirroring was successful
5. **Rollback**: Provides instructions for rolling back if needed

## Troubleshooting

### Job Failures

If the job fails, check the logs:
```bash
oc logs job/loki-minio-mirror -n openshift-logging
```

### Object Count Mismatch

If the object counts don't match, you may need to manually copy specific files:
```bash
# Get a pod from the job
POD=$(oc get pods -l job-name=loki-minio-mirror -n openshift-logging -o jsonpath='{.items[0].metadata.name}')

# Copy index files
oc exec $POD -n openshift-logging -- mc cp --recursive source/$SOURCE_BUCKET/index_* target/$TARGET_BUCKET/

# Copy chunk files
oc exec $POD -n openshift-logging -- mc cp --recursive source/$SOURCE_BUCKET/chunks/ target/$TARGET_BUCKET/
```

### Rollback

If you encounter issues after updating the LokiStack, you can rollback to the original configuration:
```bash
oc patch lokistack instance -n openshift-logging --type=merge -p '{"spec":{"storage":{"secret":{"name":"logging-loki-odf"}}}}'
```

## Advanced Options

### Customizing the Job

You can modify the `loki-minio-mirror-job.yaml` file to customize the job:

- **Resource Limits**: Add resource limits to control CPU and memory usage
- **Image**: Change the MinIO client image if needed
- **Mirror Options**: Add additional options to the `mc mirror` command

### Incremental Mirroring

For large buckets, you might want to use incremental mirroring. Modify the job to use:
```bash
mc mirror --preserve --newer source/$SOURCE_BUCKET target/$TARGET_BUCKET
```

### Bandwidth Limiting

To limit bandwidth usage, modify the job to use:
```bash
mc mirror --preserve --bandwidth 10MiB source/$SOURCE_BUCKET target/$TARGET_BUCKET
```

## Conclusion

Using a Kubernetes job with a Red Hat-based MinIO client image is an effective way to mirror Loki data within OpenShift. This approach provides automation, verification, and rollback capabilities while maintaining compatibility with Red Hat's ecosystem. 