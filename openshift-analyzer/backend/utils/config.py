import os
import yaml
import logging
from typing import Dict, Any, Optional

logger = logging.getLogger("openshift-analyzer")

def load_config(config_path: str) -> Dict[str, Any]:
    """
    Load configuration from YAML file
    
    Args:
        config_path: Path to the configuration file
        
    Returns:
        Dictionary containing the configuration
    """
    if not os.path.exists(config_path):
        logger.warning(f"Configuration file not found: {config_path}")
        return {}
    
    with open(config_path, 'r') as f:
        try:
            config = yaml.safe_load(f)
            # Process environment variables in the config
            config = process_env_vars(config)
            return config
        except yaml.YAMLError as e:
            logger.error(f"Failed to parse configuration file: {e}")
            return {}

def process_env_vars(config: Dict[str, Any]) -> Dict[str, Any]:
    """
    Process environment variables in the configuration
    
    Args:
        config: Configuration dictionary
        
    Returns:
        Configuration dictionary with environment variables resolved
    """
    if isinstance(config, dict):
        return {k: process_env_vars(v) for k, v in config.items()}
    elif isinstance(config, list):
        return [process_env_vars(item) for item in config]
    elif isinstance(config, str) and config.startswith("${") and config.endswith("}"):
        # Extract environment variable name
        env_var = config[2:-1]
        # Get the value or default
        if ":" in env_var:
            env_name, default = env_var.split(":", 1)
            return os.environ.get(env_name, default)
        else:
            return os.environ.get(env_var, "")
    else:
        return config

def get_feature_config(feature_name: str, config: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """
    Get configuration for a specific feature
    
    Args:
        feature_name: Name of the feature
        config: Optional configuration dictionary
        
    Returns:
        Feature configuration dictionary
    """
    if config is None:
        config_path = os.environ.get("CONFIG_PATH", "/app/config/config.yaml")
        config = load_config(config_path)
    
    return config.get("features", {}).get(feature_name, {}) 