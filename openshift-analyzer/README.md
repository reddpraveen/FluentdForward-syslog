# OpenShift Analyzer

An OpenShift-native troubleshooting and resource analysis web application that helps platform engineers with cluster management tasks.

## Features

- **Resource Metadata Cleaner**: Sanitize Kubernetes/OpenShift resources for reuse
- **Troubleshooting Assistant**: Analyze resources and events to suggest root causes
- **Cluster Comparison Tool**: Compare resources across clusters
- **Operator Analysis**: Check installed operators and versions
- **Extensible Plugin System**: Add new features without rebuilding the application

## Architecture

- **Frontend**: React + Material UI with Monaco Editor for YAML editing, running on UBI/NGINX
- **Backend**: FastAPI (Python) running on Red Hat UBI base image
- **Authentication**: OpenShift OAuth or LDAP integration
- **Deployment**: Kubernetes manifests with Kustomize overlays

## Directory Structure

```
openshift-analyzer/
├── backend/              # FastAPI backend application
│   ├── api/              # API routes and endpoints
│   ├── auth/             # Authentication (OAuth, LDAP)
│   ├── models/           # Data models
│   ├── services/         # Business logic services
│   ├── utils/            # Utility functions
│   └── Dockerfile        # Container image definition for backend
├── config/               # Configuration files
├── frontend/             # React frontend application
│   ├── public/           # Static assets
│   ├── src/              # React components and logic
│   ├── Dockerfile        # Container image definition for frontend
│   └── nginx.conf        # NGINX configuration for routing
├── kubernetes/           # Kubernetes/OpenShift deployment
│   ├── base/             # Base resources
│   │   ├── buildconfigs.yaml  # BuildConfig resources
│   │   └── ...           # Other base manifests
│   └── overlays/         # Environment-specific overlays
│       ├── dev/          # Development environment
│       └── prod/         # Production environment
└── plugins/              # Extensible plugin system
    ├── examples/         # Example plugins
    └── lib/              # Plugin libraries and utilities
```

## Building Container Images

### Option 1: Building Locally

If you have Docker or Podman installed, you can build the images locally:

```bash
# Build backend image
cd openshift-analyzer
podman build -t openshift-analyzer-backend:latest -f backend/Dockerfile backend/

# Build frontend image
podman build -t openshift-analyzer-frontend:latest -f frontend/Dockerfile frontend/

# Tag and push to a registry
podman tag openshift-analyzer-backend:latest <registry>/openshift-analyzer-backend:latest
podman tag openshift-analyzer-frontend:latest <registry>/openshift-analyzer-frontend:latest

podman push <registry>/openshift-analyzer-backend:latest
podman push <registry>/openshift-analyzer-frontend:latest
```

### Option 2: Using OpenShift BuildConfigs

This approach uses OpenShift's built-in build capabilities:

```bash
# Create the namespace
oc new-project openshift-analyzer-ns

# Apply build configs and image streams
oc apply -f kubernetes/base/buildconfigs.yaml

# Start the builds
oc start-build openshift-analyzer-backend
oc start-build openshift-analyzer-frontend
```

## Installation

### Prerequisites

- OpenShift 4.14+ cluster
- `oc` command-line tool with admin privileges

### Deploy to OpenShift

1. Create the namespace:

```bash
oc new-project openshift-analyzer-ns
```

2. Build the container images using one of the methods above.

3. Deploy the application:

```bash
# For development environment
oc apply -k kubernetes/overlays/dev

# For production environment
oc apply -k kubernetes/overlays/prod
```

4. Set up OAuth integration (for production):

```bash
# Create OAuth client
oc create -f - <<EOF
apiVersion: oauth.openshift.io/v1
kind: OAuthClient
metadata:
  name: openshift-analyzer
redirectURIs:
- https://$(oc get route prod-openshift-analyzer -n openshift-analyzer-ns -o jsonpath='{.spec.host}')/auth/callback
grantMethod: auto
EOF

# Update OAuth client secret
oc create secret generic prod-openshift-analyzer-auth \
  --from-literal=oauth-client-id=openshift-analyzer \
  --from-literal=oauth-client-secret=$(openssl rand -base64 32) \
  --from-literal=oauth-redirect-uri=https://$(oc get route prod-openshift-analyzer -n openshift-analyzer-ns -o jsonpath='{.spec.host}')/auth/callback \
  -n openshift-analyzer-ns
```

## Development

### Backend Development

1. Install dependencies:

```bash
cd backend
pip install -r requirements.txt
```

2. Run locally:

```bash
CONFIG_PATH=../config/config.yaml python main.py
```

### Frontend Development

1. Install dependencies:

```bash
cd frontend
npm install
```

2. Run development server:

```bash
npm start
```

### Development in Containers

You can also develop using containers for consistency with production:

```bash
# Backend development container
podman run -it --rm -v $(pwd)/backend:/app:Z -p 8080:8080 registry.access.redhat.com/ubi9/python-311:latest bash
cd /app
pip install -r requirements.txt
python main.py

# Frontend development container
podman run -it --rm -v $(pwd)/frontend:/app:Z -p 3000:3000 registry.access.redhat.com/ubi9/nodejs-18:latest bash
cd /app
npm install
npm start
```

## Extending with Plugins

The OpenShift Analyzer supports plugins to extend its functionality:

1. Create a new plugin in the `plugins` directory
2. Follow the plugin interface defined in `plugins/lib`
3. Plugins are automatically discovered and loaded at startup

## License

Apache License 2.0 