from fastapi import APIRouter, Depends, HTTPException, Path, Query
from kubernetes import client, config
from kubernetes.client.rest import ApiException
import yaml
import json
from typing import List, Dict, Any, Optional
from pydantic import BaseModel

router = APIRouter()

# Models
class Resource(BaseModel):
    """Kubernetes resource model"""
    kind: str
    apiVersion: str
    metadata: Dict[str, Any]
    spec: Optional[Dict[str, Any]] = None
    status: Optional[Dict[str, Any]] = None

class ClusterInfo(BaseModel):
    """OpenShift cluster information"""
    name: str
    version: str
    platform: str
    api_url: str

class NamespaceInfo(BaseModel):
    """Namespace information"""
    name: str
    status: str
    labels: Optional[Dict[str, str]] = None
    annotations: Optional[Dict[str, str]] = None

class OperatorInfo(BaseModel):
    """Operator information"""
    name: str
    namespace: str
    version: str
    channel: Optional[str] = None
    csv_name: Optional[str] = None

# API Endpoints

@router.get("/resources/{namespace}/{kind}/{name}", response_model=Resource)
async def get_resource(
    namespace: str = Path(..., description="Namespace of the resource"),
    kind: str = Path(..., description="Kind of the resource (e.g., Deployment, Service)"),
    name: str = Path(..., description="Name of the resource"),
    sanitize: bool = Query(False, description="Whether to sanitize the resource metadata")
):
    """
    Get a Kubernetes resource by namespace, kind and name
    """
    try:
        api_client = client.ApiClient()
        
        # Determine the correct API based on resource kind
        resource_info = get_resource_api_info(kind)
        if not resource_info:
            raise HTTPException(status_code=400, detail=f"Unknown resource kind: {kind}")
        
        # Call the appropriate API
        api_version = resource_info["api_version"]
        group = resource_info["group"]
        version = resource_info["version"]
        plural = resource_info["plural"]
        
        if group:
            # Custom resource
            custom_api = client.CustomObjectsApi(api_client)
            resource = custom_api.get_namespaced_custom_object(
                group, version, namespace, plural, name
            )
        else:
            # Core resource
            if kind == "Pod":
                resource = client.CoreV1Api(api_client).read_namespaced_pod(name, namespace)
            elif kind == "Service":
                resource = client.CoreV1Api(api_client).read_namespaced_service(name, namespace)
            elif kind == "ConfigMap":
                resource = client.CoreV1Api(api_client).read_namespaced_config_map(name, namespace)
            elif kind == "Secret":
                resource = client.CoreV1Api(api_client).read_namespaced_secret(name, namespace)
            elif kind == "Deployment":
                resource = client.AppsV1Api(api_client).read_namespaced_deployment(name, namespace)
            else:
                raise HTTPException(status_code=400, detail=f"Unsupported resource kind: {kind}")

            # Convert to dict
            resource = api_client.sanitize_for_serialization(resource)
        
        # Sanitize if requested
        if sanitize:
            resource = sanitize_resource(resource)
            
        return resource
    
    except ApiException as e:
        if e.status == 404:
            raise HTTPException(status_code=404, detail=f"Resource {kind}/{name} not found in namespace {namespace}")
        else:
            raise HTTPException(status_code=e.status, detail=str(e))

@router.get("/namespaces", response_model=List[NamespaceInfo])
async def list_namespaces():
    """
    List all namespaces in the cluster
    """
    try:
        api_client = client.ApiClient()
        core_v1 = client.CoreV1Api(api_client)
        namespaces = core_v1.list_namespace()
        
        result = []
        for ns in namespaces.items:
            ns_dict = api_client.sanitize_for_serialization(ns)
            result.append({
                "name": ns_dict["metadata"]["name"],
                "status": ns_dict["status"]["phase"],
                "labels": ns_dict["metadata"].get("labels"),
                "annotations": ns_dict["metadata"].get("annotations")
            })
            
        return result
        
    except ApiException as e:
        raise HTTPException(status_code=e.status, detail=str(e))

@router.get("/operators", response_model=List[OperatorInfo])
async def list_operators():
    """
    List all installed operators in the cluster
    """
    try:
        api_client = client.ApiClient()
        custom_api = client.CustomObjectsApi(api_client)
        
        # List ClusterServiceVersions (CSVs) across all namespaces
        csvs = custom_api.list_cluster_custom_object(
            "operators.coreos.com", 
            "v1alpha1", 
            "clusterserviceversions"
        )
        
        result = []
        for csv in csvs.get("items", []):
            result.append({
                "name": csv["spec"]["displayName"],
                "namespace": csv["metadata"]["namespace"],
                "version": csv["spec"]["version"],
                "channel": csv["spec"].get("channel"),
                "csv_name": csv["metadata"]["name"]
            })
            
        return result
        
    except ApiException as e:
        raise HTTPException(status_code=e.status, detail=str(e))

@router.get("/cluster", response_model=ClusterInfo)
async def get_cluster_info():
    """
    Get information about the current OpenShift cluster
    """
    try:
        api_client = client.ApiClient()
        version_api = client.VersionApi(api_client)
        version_info = version_api.get_code()
        
        # Get cluster version from OpenShift API
        custom_api = client.CustomObjectsApi(api_client)
        cluster_version = custom_api.get_cluster_custom_object(
            "config.openshift.io", 
            "v1", 
            "clusterversions",
            "version"
        )
        
        # Get infrastructure info
        infra = custom_api.get_cluster_custom_object(
            "config.openshift.io", 
            "v1", 
            "infrastructures",
            "cluster"
        )
        
        result = {
            "name": infra["spec"].get("infrastructureName", "Unknown"),
            "version": cluster_version["status"]["desired"]["version"],
            "platform": infra["status"]["platform"],
            "api_url": infra["status"]["apiServerURL"]
        }
            
        return result
        
    except ApiException as e:
        raise HTTPException(status_code=e.status, detail=str(e))

# Helper functions
def get_resource_api_info(kind: str) -> Dict[str, str]:
    """
    Get API information for a given resource kind
    """
    # Map of resource kinds to API versions and plurals
    resource_map = {
        "Pod": {"api_version": "v1", "group": "", "version": "v1", "plural": "pods"},
        "Service": {"api_version": "v1", "group": "", "version": "v1", "plural": "services"},
        "ConfigMap": {"api_version": "v1", "group": "", "version": "v1", "plural": "configmaps"},
        "Secret": {"api_version": "v1", "group": "", "version": "v1", "plural": "secrets"},
        "Deployment": {"api_version": "apps/v1", "group": "apps", "version": "v1", "plural": "deployments"},
        "StatefulSet": {"api_version": "apps/v1", "group": "apps", "version": "v1", "plural": "statefulsets"},
        "DaemonSet": {"api_version": "apps/v1", "group": "apps", "version": "v1", "plural": "daemonsets"},
        "Route": {"api_version": "route.openshift.io/v1", "group": "route.openshift.io", "version": "v1", "plural": "routes"},
        "DeploymentConfig": {"api_version": "apps.openshift.io/v1", "group": "apps.openshift.io", "version": "v1", "plural": "deploymentconfigs"},
        "Build": {"api_version": "build.openshift.io/v1", "group": "build.openshift.io", "version": "v1", "plural": "builds"},
        "BuildConfig": {"api_version": "build.openshift.io/v1", "group": "build.openshift.io", "version": "v1", "plural": "buildconfigs"},
        "CronJob": {"api_version": "batch/v1", "group": "batch", "version": "v1", "plural": "cronjobs"},
        "Job": {"api_version": "batch/v1", "group": "batch", "version": "v1", "plural": "jobs"},
        "PersistentVolumeClaim": {"api_version": "v1", "group": "", "version": "v1", "plural": "persistentvolumeclaims"},
        "PersistentVolume": {"api_version": "v1", "group": "", "version": "v1", "plural": "persistentvolumes"},
        "Ingress": {"api_version": "networking.k8s.io/v1", "group": "networking.k8s.io", "version": "v1", "plural": "ingresses"},
        "MachineSet": {"api_version": "machine.openshift.io/v1beta1", "group": "machine.openshift.io", "version": "v1beta1", "plural": "machinesets"},
        "Machine": {"api_version": "machine.openshift.io/v1beta1", "group": "machine.openshift.io", "version": "v1beta1", "plural": "machines"},
        "ClusterOperator": {"api_version": "config.openshift.io/v1", "group": "config.openshift.io", "version": "v1", "plural": "clusteroperators"},
    }
    
    return resource_map.get(kind, None)

def sanitize_resource(resource: Dict[str, Any]) -> Dict[str, Any]:
    """
    Sanitize a resource by removing non-reusable fields
    """
    fields_to_remove = [
        "status",
        "metadata.managedFields",
        "metadata.creationTimestamp",
        "metadata.resourceVersion",
        "metadata.selfLink",
        "metadata.uid",
        "metadata.generation",
        "metadata.annotations.kubectl.kubernetes.io/last-applied-configuration"
    ]
    
    # Deep copy to avoid modifying the original
    sanitized = json.loads(json.dumps(resource))
    
    for field in fields_to_remove:
        parts = field.split(".")
        current = sanitized
        
        # Navigate to the nested field
        for i, part in enumerate(parts):
            if i == len(parts) - 1:
                # Last part, remove it
                if part in current:
                    del current[part]
            else:
                # Navigate deeper
                if part in current and isinstance(current[part], dict):
                    current = current[part]
                else:
                    # Path doesn't exist, stop
                    break
                    
    return sanitized 