import os
import yaml
import logging
from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.security import OAuth2PasswordBearer
from kubernetes import client, config

# Import local modules
from api.routes import router as api_router
from auth.oauth import router as oauth_router
from auth.ldap import router as ldap_router
from utils.config import load_config

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("openshift-analyzer")

# Load configuration
config_path = os.environ.get("CONFIG_PATH", "/app/config/config.yaml")
try:
    app_config = load_config(config_path)
    logger.info(f"Configuration loaded from {config_path}")
except Exception as e:
    logger.error(f"Failed to load configuration: {e}")
    app_config = {}

# Initialize FastAPI app
app = FastAPI(
    title=app_config.get("app", {}).get("name", "OpenShift Analyzer"),
    description=app_config.get("app", {}).get("description", "OpenShift resource analysis tool"),
    version=app_config.get("app", {}).get("version", "1.0.0"),
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=app_config.get("server", {}).get("cors", {}).get("origins", ["*"]),
    allow_credentials=True,
    allow_methods=app_config.get("server", {}).get("cors", {}).get("methods", ["*"]),
    allow_headers=app_config.get("server", {}).get("cors", {}).get("headers", ["*"]),
)

# Initialize Kubernetes client
try:
    if app_config.get("kubernetes", {}).get("in_cluster", True):
        config.load_incluster_config()
        logger.info("Loaded in-cluster Kubernetes configuration")
    else:
        kubeconfig_path = app_config.get("kubernetes", {}).get("kubeconfig_path")
        if kubeconfig_path and os.path.exists(kubeconfig_path):
            config.load_kube_config(kubeconfig_path)
            logger.info(f"Loaded Kubernetes configuration from {kubeconfig_path}")
        else:
            config.load_kube_config()
            logger.info("Loaded default Kubernetes configuration")
except Exception as e:
    logger.error(f"Failed to load Kubernetes configuration: {e}")

# Mount API router
app.include_router(api_router, prefix="/api", tags=["api"])

# Configure authentication based on config
auth_enabled = app_config.get("auth", {}).get("enabled", False)
auth_type = app_config.get("auth", {}).get("type", "none")

if auth_enabled:
    if auth_type == "oauth":
        app.include_router(oauth_router, prefix="/auth", tags=["auth"])
        logger.info("OAuth authentication enabled")
    elif auth_type == "ldap":
        app.include_router(ldap_router, prefix="/auth", tags=["auth"])
        logger.info("LDAP authentication enabled")
    else:
        logger.warn(f"Unknown authentication type: {auth_type}")

# Mount static files (frontend)
try:
    app.mount("/", StaticFiles(directory="/app/frontend", html=True), name="frontend")
    logger.info("Mounted frontend static files")
except Exception as e:
    logger.warning(f"Failed to mount frontend static files: {e}")

@app.get("/health")
async def health_check():
    """Health check endpoint for liveness/readiness probes"""
    return {"status": "ok"}

@app.get("/config")
async def get_public_config():
    """Returns public configuration for frontend"""
    public_config = {
        "app": app_config.get("app", {}),
        "features": {
            "metadata_cleaner": {
                "enabled": app_config.get("features", {}).get("metadata_cleaner", {}).get("enabled", True)
            },
            "troubleshooter": {
                "enabled": app_config.get("features", {}).get("troubleshooter", {}).get("enabled", True),
                "kb_search": {
                    "enabled": app_config.get("features", {}).get("troubleshooter", {}).get("kb_search", {}).get("enabled", True)
                }
            },
            "cluster_comparison": {
                "enabled": app_config.get("features", {}).get("cluster_comparison", {}).get("enabled", True),
                "default_resource_types": app_config.get("features", {}).get("cluster_comparison", {}).get("default_resource_types", [])
            },
            "operator_analysis": {
                "enabled": app_config.get("features", {}).get("operator_analysis", {}).get("enabled", True)
            }
        },
        "auth": {
            "enabled": auth_enabled,
            "type": auth_type
        }
    }
    return public_config

@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Middleware to log all requests"""
    logger.info(f"{request.method} {request.url.path}")
    response = await call_next(request)
    return response

if __name__ == "__main__":
    import uvicorn
    
    host = app_config.get("server", {}).get("host", "0.0.0.0")
    port = int(app_config.get("server", {}).get("port", 8080))
    debug = app_config.get("server", {}).get("debug", False)
    
    uvicorn.run("main:app", host=host, port=port, reload=debug) 