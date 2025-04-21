### SIMPLIFIED APPROACH WITHOUT NODE.JS BUILD ###
FROM registry.access.redhat.com/ubi9/nginx-120:latest

# Copy static frontend files directly
WORKDIR /usr/share/nginx/html

# Create a minimal frontend directly
USER 0
RUN cat > index.html << 'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>OpenShift Analyzer</title>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Roboto:300,400,500,700&display=swap" />
  <link rel="stylesheet" href="https://fonts.googleapis.com/icon?family=Material+Icons" />
  <style>
    body { margin: 0; font-family: "Roboto", sans-serif; }
    .app-container { display: flex; flex-direction: column; height: 100vh; }
    .app-header { background-color: #1976d2; color: white; padding: 12px 24px; box-shadow: 0 2px 4px rgba(0,0,0,0.2); }
    .app-content { padding: 24px; flex-grow: 1; background-color: #f5f5f5; }
    .card { background-color: white; border-radius: 4px; box-shadow: 0 1px 3px rgba(0,0,0,0.12); padding: 16px; margin-bottom: 16px; }
    .button { background-color: #1976d2; color: white; border: none; padding: 8px 16px; border-radius: 4px; cursor: pointer; }
    .nav-tabs { display: flex; margin-bottom: 24px; border-bottom: 1px solid #ddd; }
    .tab { padding: 8px 16px; cursor: pointer; margin-right: 8px; }
    .tab.active { border-bottom: 2px solid #1976d2; color: #1976d2; }
  </style>
</head>
<body>
  <div class="app-container">
    <header class="app-header">
      <h1>OpenShift Analyzer</h1>
    </header>
    <main class="app-content">
      <div class="nav-tabs">
        <div class="tab active">Resource Cleaner</div>
        <div class="tab">Troubleshooter</div>
        <div class="tab">Cluster Comparison</div>
        <div class="tab">Operator Analysis</div>
      </div>
      <div class="card">
        <h2>Resource Metadata Cleaner</h2>
        <p>Clean Kubernetes resources by removing non-reusable fields like status, managedFields, etc.</p>
        <p>The full functionality requires the React application to be built, which is currently not possible due to technical limitations.</p>
        <p>Please use the backend API directly at <code>/api/resources/{namespace}/{kind}/{name}?sanitize=true</code></p>
      </div>
      <div class="card">
        <h2>Backend Connection Status</h2>
        <p>Checking connection to backend services...</p>
        <button class="button" onclick="checkBackend()">Check Connection</button>
        <div id="connection-status"></div>
      </div>
    </main>
  </div>

  <script>
    function checkBackend() {
      const statusEl = document.getElementById('connection-status');
      statusEl.textContent = 'Connecting...';
      
      fetch('/api/health')
        .then(response => {
          if (response.ok) return response.json();
          throw new Error('Backend not available');
        })
        .then(data => {
          statusEl.textContent = 'Connected to backend! Status: ' + data.status;
        })
        .catch(error => {
          statusEl.textContent = 'Error connecting to backend: ' + error.message;
        });
    }
  </script>
</body>
</html>
EOL

# Configure NGINX
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Ensure proper permissions for nginx
RUN chmod -R g+w /usr/share/nginx/html && \
    chown -R 1001:0 /usr/share/nginx/html

# Switch to non-root user
USER 1001

# Expose port
EXPOSE 8080

# Run NGINX
CMD ["nginx", "-g", "daemon off;"] 