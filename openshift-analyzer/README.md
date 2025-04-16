# OpenShift Analyzer

An OpenShift-native troubleshooting and resource analysis web application that helps platform engineers with cluster management tasks.

## Features

- **Resource Metadata Cleaner**: Sanitize Kubernetes/OpenShift resources for reuse
- **Troubleshooting Assistant**: Analyze resources and events to suggest root causes
- **Cluster Comparison Tool**: Compare resources across clusters
- **Operator Analysis**: Check installed operators and versions
- **Extensible Plugin System**: Add new features without rebuilding the application

## Architecture

- **Frontend**: React + Material UI with Monaco Editor for YAML editing
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
│   └── utils/            # Utility functions
├── config/               # Configuration files
├── frontend/             # React frontend application
│   ├── public/           # Static assets
│   └── src/              # React components and logic
├── kubernetes/           # Kubernetes/OpenShift deployment
│   ├── base/             # Base resources
│   └── overlays/         # Environment-specific overlays
│       ├── dev/          # Development environment
│       └── prod/         # Production environment
└── plugins/              # Extensible plugin system
    ├── examples/         # Example plugins
    └── lib/              # Plugin libraries and utilities
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

2. Deploy the application:

```bash
# For development environment
oc apply -k kubernetes/overlays/dev

# For production environment
oc apply -k kubernetes/overlays/prod
```

3. Set up OAuth integration (for production):

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

## Extending with Plugins

The OpenShift Analyzer supports plugins to extend its functionality:

1. Create a new plugin in the `plugins` directory
2. Follow the plugin interface defined in `plugins/lib`
3. Plugins are automatically discovered and loaded at startup

## License

Apache License 2.0 