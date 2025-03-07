const express = require('express');
const https = require('https');
const fs = require('fs');
const path = require('path');
const k8s = require('@kubernetes/client-node');
const app = express();
const PORT = process.env.PORT || 8080;

// Load configuration
const config = JSON.parse(fs.readFileSync('/app/config/config.json'));

// Set up Kubernetes client
const kc = new k8s.KubeConfig();
kc.loadFromDefault();
const k8sApi = kc.makeApiClient(k8s.CoreV1Api);
const appsApi = kc.makeApiClient(k8s.AppsV1Api);
const customApi = kc.makeApiClient(k8s.CustomObjectsApi);

// Serve static frontend files
app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

// Middleware to parse query parameters
app.use((req, res, next) => {
  req.query.namespace = req.query.namespace || config.defaultNamespace;
  req.query.simplified = req.query.simplified !== 'false';
  next();
});

// Get all namespaces
app.get('/api/namespaces', async (req, res) => {
  try {
    const { body } = await k8sApi.listNamespace();
    let namespaces = body.items.map(item => ({
      name: item.metadata.name,
      status: item.status.phase,
      creationTimestamp: item.metadata.creationTimestamp
    }));
    
    if (config.hideSystemNamespaces) {
      namespaces = namespaces.filter(ns => 
        !ns.name.startsWith('kube-') && 
        !ns.name.startsWith('openshift-') && 
        ns.name !== 'default');
    }
    
    res.json(namespaces);
  } catch (err) {
    console.error('Error fetching namespaces:', err);
    res.status(500).json({ error: err.message });
  }
});

// Get pods in a namespace
app.get('/api/namespaces/:namespace/pods', async (req, res) => {
  try {
    const namespace = req.params.namespace;
    const { body } = await k8sApi.listNamespacedPod(namespace);
    
    let pods = body.items;
    if (req.query.simplified === 'true') {
      pods = pods.map(simplifyResource);
    }
    
    res.json(pods);
  } catch (err) {
    console.error(`Error fetching pods in ${req.params.namespace}:`, err);
    res.status(500).json({ error: err.message });
  }
});

// Get deployments in a namespace
app.get('/api/namespaces/:namespace/deployments', async (req, res) => {
  try {
    const namespace = req.params.namespace;
    const { body } = await appsApi.listNamespacedDeployment(namespace);
    
    let deployments = body.items;
    if (req.query.simplified === 'true') {
      deployments = deployments.map(simplifyResource);
    }
    
    res.json(deployments);
  } catch (err) {
    console.error(`Error fetching deployments in ${req.params.namespace}:`, err);
    res.status(500).json({ error: err.message });
  }
});

// Get services in a namespace
app.get('/api/namespaces/:namespace/services', async (req, res) => {
  try {
    const namespace = req.params.namespace;
    const { body } = await k8sApi.listNamespacedService(namespace);
    
    let services = body.items;
    if (req.query.simplified === 'true') {
      services = services.map(simplifyResource);
    }
    
    res.json(services);
  } catch (err) {
    console.error(`Error fetching services in ${req.params.namespace}:`, err);
    res.status(500).json({ error: err.message });
  }
});

// Get routes in a namespace
app.get('/api/namespaces/:namespace/routes', async (req, res) => {
  try {
    const namespace = req.params.namespace;
    const { body } = await customApi.listNamespacedCustomObject(
      'route.openshift.io',
      'v1',
      namespace,
      'routes'
    );
    
    let routes = body.items;
    if (req.query.simplified === 'true') {
      routes = routes.map(simplifyResource);
    }
    
    res.json(routes);
  } catch (err) {
    console.error(`Error fetching routes in ${req.params.namespace}:`, err);
    res.status(500).json({ error: err.message });
  }
});

// Function to simplify resources by removing unnecessary fields
function simplifyResource(resource) {
  if (!resource) return resource;
  
  // Create a deep copy
  const simplified = JSON.parse(JSON.stringify(resource));
  
  // Remove hidden fields
  if (config.hiddenFields.includes('managedFields')) {
    delete simplified.metadata.managedFields;
  }
  
  // Remove system annotations
  if (simplified.metadata && simplified.metadata.annotations) {
    for (const key of Object.keys(simplified.metadata.annotations)) {
      if (config.hiddenFields.some(pattern => key.startsWith(pattern))) {
        delete simplified.metadata.annotations[key];
      }
    }
    
    // Remove annotations object if empty
    if (Object.keys(simplified.metadata.annotations).length === 0) {
      delete simplified.metadata.annotations;
    }
  }
  
  // Simplify status if needed
  if (config.hiddenFields.includes('status.conditions') && simplified.status && simplified.status.conditions) {
    delete simplified.status.conditions;
  }
  
  return simplified;
}

// Start the server
app.listen(PORT, () => {
  console.log(`OpenShift Manifest Viewer running on port ${PORT}`);
});
