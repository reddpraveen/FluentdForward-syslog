const { useState, useEffect } = React;

// Main App Component
function App() {
  const [namespaces, setNamespaces] = useState([]);
  const [selectedNamespace, setSelectedNamespace] = useState('');
  const [resourceType, setResourceType] = useState('pods');
  const [resources, setResources] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [viewMode, setViewMode] = useState('simplified'); // 'simplified' or 'full'
  const [selectedResource, setSelectedResource] = useState(null);
  
  // Fetch namespaces on initial load
  useEffect(() => {
    fetchNamespaces();
  }, []);
  
  // Fetch resources when namespace or resource type changes
  useEffect(() => {
    if (selectedNamespace) {
      fetchResources();
    }
  }, [selectedNamespace, resourceType, viewMode]);
  
  const fetchNamespaces = async () => {
    try {
      setLoading(true);
      const response = await fetch('/api/namespaces');
      if (!response.ok) throw new Error('Failed to fetch namespaces');
      
      const data = await response.json();
      setNamespaces(data);
      if (data.length > 0) {
        setSelectedNamespace(data[0].name);
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };
  
  const fetchResources = async () => {
    try {
      setLoading(true);
      const simplified = viewMode === 'simplified';
      const response = await fetch(`/api/namespaces/${selectedNamespace}/${resourceType}?simplified=${simplified}`);
      if (!response.ok) throw new Error(`Failed to fetch ${resourceType}`);
      
      const data = await response.json();
      setResources(data);
      setSelectedResource(null);
    } catch (err) {
      setError(err.message);
      setResources([]);
    } finally {
      setLoading(false);
    }
  };
  
  const handleResourceClick = (resource) => {
    setSelectedResource(resource);
  };
  
  const handleExportYAML = () => {
    if (!selectedResource) return;
    
    const yaml = jsYaml.dump(selectedResource);
    const blob = new Blob([yaml], { type: 'text/yaml' });
    const url = URL.createObjectURL(blob);
    
    const a = document.createElement('a');
    a.href = url;
    a.download = `${selectedResource.metadata.name}.yaml`;
    a.click();
    
    URL.revokeObjectURL(url);
  };
  
  return (
    <div className="container mx-auto p-4">
      <header className="bg-blue-600 text-white p-4 rounded-t-lg shadow-md">
        <h1 className="text-2xl font-bold">OpenShift Manifest Viewer</h1>
      </header>
      
      {error && (
        <div className="bg-red-100 border-l-4 border-red-500 text-red-700 p-4 my-4" role="alert">
          <p>{error}</p>
        </div>
      )}
      
      <div className="bg-white p-4 shadow-md rounded-b-lg mb-6">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Namespace</label>
            <select 
              className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
              value={selectedNamespace}
              onChange={(e) => setSelectedNamespace(e.target.value)}
            >
              {namespaces.map(ns => (
                <option key={ns.name} value={ns.name}>{ns.name}</option>
              ))}
            </select>
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Resource Type</label>
            <select 
              className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
              value={resourceType}
              onChange={(e) => setResourceType(e.target.value)}
            >
              <option value="pods">Pods</option>
              <option value="deployments">Deployments</option>
              <option value="services">Services</option>
              <option value="routes">Routes</option>
            </select>
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">View Mode</label>
            <select 
              className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
              value={viewMode}
              onChange={(e) => setViewMode(e.target.value)}
            >
              <option value="simplified">Simplified</option>
              <option value="full">Full Details</option>
            </select>
          </div>
          
          <div className="flex items-end">
            <button 
              className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline"
              onClick={fetchResources}
            >
              Refresh
            </button>
          </div>
        </div>
      </div>
      
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-1 bg-white p-4 rounded-lg shadow-md">
          <h2 className="text-xl font-semibold mb-4">{resourceType.charAt(0).toUpperCase() + resourceType.slice(1)}</h2>
          
          {loading ? (
            <div className="text-center py-4">Loading...</div>
          ) : resources.length === 0 ? (
            <div className="text-center py-4 text-gray-500">No resources found</div>
          ) : (
            <ul className="divide-y divide-gray-200">
              {resources.map(resource => (
                <li 
                  key={resource.metadata.uid} 
                  className={`py-3 px-2 cursor-pointer hover:bg-gray-50 ${selectedResource && selectedResource.metadata.uid === resource.metadata.uid ? 'bg-blue-50' : ''}`}
                  onClick={() => handleResourceClick(resource)}
                >
                  <div className="flex justify-between">
                    <div className="font-medium">{resource.metadata.name}</div>
                    <div className="text-sm text-gray-500">
                      {resource.status && resource.status.phase ? resource.status.phase : ''}
                    </div>
                  </div>
                  {resource.metadata.labels && (
                    <div className="mt-1 flex flex-wrap gap-1">
                      {Object.entries(resource.metadata.labels).map(([key, value]) => (
                        <span key={key} className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                          {key}={value}
                        </span>
                      ))}
                    </div>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>
        
        <div className="lg:col-span-2 bg-white p-4 rounded-lg shadow-md">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-xl font-semibold">Resource Details</h2>
            {selectedResource && (
              <button 
                className="bg-green-500 hover:bg-green-700 text-white font-bold py-1 px-3 rounded text-sm focus:outline-none focus:shadow-outline"
                onClick={handleExportYAML}
              >
                Export YAML
              </button>
            )}
          </div>
          
          {selectedResource ? (
            <div className="overflow-auto">
              <ResourceDetails resource={selectedResource} />
            </div>
          ) : (
            <div className="text-center py-16 text-gray-500">
              Select a resource to view details
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// Resource Details Component
function ResourceDetails({ resource }) {
  const sections = [
    { title: 'Metadata', content: resource.metadata },
    { title: 'Spec', content: resource.spec },
    { title: 'Status', content: resource.status }
  ].filter(section => section.content);
  
  return (
    <div className="space-y-4">
      {sections.map((section, index) => (
        <div key={index} className="border border-gray-200 rounded-md">
          <div className="bg-gray-50 px-4 py-2 font-medium">{section.title}</div>
          <div className="p-4">
            <pre className="text-sm overflow-auto whitespace-pre-wrap">
              {JSON.stringify(section.content, null, 2)}
            </pre>
          </div>
        </div>
      ))}
    </div>
  );
}

// Render the App
ReactDOM.render(<App />, document.getElementById('root'));
