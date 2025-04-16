import os
import logging
import json
import ldap
from fastapi import APIRouter, Depends, HTTPException, Request, Form
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from typing import Dict, Any, Optional, List
import jwt
from datetime import datetime, timedelta
from utils.config import load_config

router = APIRouter()
logger = logging.getLogger("openshift-analyzer")

# Load configuration
config_path = os.environ.get("CONFIG_PATH", "/app/config/config.yaml")
app_config = load_config(config_path)
ldap_config = app_config.get("auth", {}).get("ldap", {})

# Models
class Token(BaseModel):
    access_token: str
    token_type: str
    expires_in: int

class User(BaseModel):
    username: str
    email: Optional[str] = None
    full_name: Optional[str] = None
    groups: Optional[List[str]] = None

# LDAP configuration from environment variables
LDAP_SERVER = os.environ.get("LDAP_SERVER", ldap_config.get("server", ""))
LDAP_PORT = int(os.environ.get("LDAP_PORT", ldap_config.get("port", "389")))
LDAP_BIND_DN = os.environ.get("LDAP_BIND_DN", ldap_config.get("bind_dn", ""))
LDAP_BIND_PASSWORD = os.environ.get("LDAP_BIND_PASSWORD", ldap_config.get("bind_password", ""))
LDAP_SEARCH_BASE = os.environ.get("LDAP_SEARCH_BASE", ldap_config.get("search_base", ""))
LDAP_SEARCH_FILTER = os.environ.get("LDAP_SEARCH_FILTER", ldap_config.get("search_filter", "(uid=%s)"))
LDAP_USE_SSL = os.environ.get("LDAP_USE_SSL", "false").lower() == "true"
JWT_SECRET_KEY = os.environ.get("JWT_SECRET_KEY", "openshift-analyzer-secret-key")
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION = 3600  # 1 hour

# Configure OAuth2
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")

@router.post("/token", response_model=Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    """Authenticate user with LDAP and return JWT token"""
    try:
        user = authenticate_ldap(form_data.username, form_data.password)
        if not user:
            raise HTTPException(status_code=401, detail="Invalid credentials")
            
        # Create JWT token
        token = create_jwt_token(user)
        
        return {
            "access_token": token,
            "token_type": "bearer",
            "expires_in": JWT_EXPIRATION
        }
    except Exception as e:
        logger.error(f"LDAP authentication error: {str(e)}")
        raise HTTPException(status_code=401, detail="Authentication error")

@router.get("/user", response_model=User)
async def get_current_user(token: str = Depends(oauth2_scheme)):
    """Get current user info from JWT token"""
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        if datetime.fromtimestamp(payload["exp"]) < datetime.now():
            raise HTTPException(status_code=401, detail="Token expired")
            
        return {
            "username": payload["sub"],
            "email": payload.get("email"),
            "full_name": payload.get("name"),
            "groups": payload.get("groups", [])
        }
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
        
@router.get("/logout")
async def logout():
    """Logout (client-side only)"""
    # JWT tokens are stateless, so server-side logout is not needed
    # The client should discard the token
    return {"detail": "Logged out successfully"}

def authenticate_ldap(username: str, password: str) -> Optional[Dict[str, Any]]:
    """
    Authenticate user with LDAP
    
    Args:
        username: Username
        password: Password
        
    Returns:
        User information if authentication is successful, None otherwise
    """
    if not all([LDAP_SERVER, LDAP_SEARCH_BASE, LDAP_SEARCH_FILTER]):
        logger.error("LDAP configuration missing")
        return None
        
    try:
        # Connect to LDAP server
        ldap_uri = f"ldap{'s' if LDAP_USE_SSL else ''}://{LDAP_SERVER}:{LDAP_PORT}"
        ldap_client = ldap.initialize(ldap_uri)
        ldap_client.set_option(ldap.OPT_REFERRALS, 0)
        
        if LDAP_USE_SSL:
            ldap_client.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)
            
        # If admin bind credentials are provided, use them to search for the user
        if LDAP_BIND_DN and LDAP_BIND_PASSWORD:
            ldap_client.simple_bind_s(LDAP_BIND_DN, LDAP_BIND_PASSWORD)
            search_filter = LDAP_SEARCH_FILTER.replace("%s", username)
            
            # Search for the user
            result = ldap_client.search_s(
                LDAP_SEARCH_BASE,
                ldap.SCOPE_SUBTREE,
                search_filter,
                ["uid", "mail", "cn", "memberOf"]
            )
            
            if not result or len(result) != 1:
                logger.error(f"User not found or multiple users found: {username}")
                return None
                
            user_dn = result[0][0]
            user_attributes = result[0][1]
            
            # Authenticate with the user's credentials
            ldap_client.simple_bind_s(user_dn, password)
            
            # Extract user attributes
            user_info = {
                "username": username,
                "dn": user_dn
            }
            
            if "mail" in user_attributes:
                user_info["email"] = user_attributes["mail"][0].decode("utf-8")
                
            if "cn" in user_attributes:
                user_info["full_name"] = user_attributes["cn"][0].decode("utf-8")
                
            # Extract groups
            if "memberOf" in user_attributes:
                groups = []
                for group_dn in user_attributes["memberOf"]:
                    group_dn = group_dn.decode("utf-8")
                    # Extract group name from DN
                    for part in group_dn.split(","):
                        if part.startswith("cn="):
                            groups.append(part[3:])
                            break
                user_info["groups"] = groups
                
            return user_info
        else:
            # Direct bind with the user's credentials
            user_dn = LDAP_SEARCH_FILTER.replace("%s", username)
            ldap_client.simple_bind_s(user_dn, password)
            
            return {
                "username": username,
                "dn": user_dn
            }
            
    except ldap.INVALID_CREDENTIALS:
        logger.error(f"Invalid credentials for user: {username}")
        return None
    except ldap.SERVER_DOWN:
        logger.error("LDAP server is down")
        return None
    except ldap.LDAPError as e:
        logger.error(f"LDAP error: {str(e)}")
        return None
    finally:
        ldap_client.unbind_s()

def create_jwt_token(user: Dict[str, Any]) -> str:
    """
    Create JWT token for the user
    
    Args:
        user: User information
        
    Returns:
        JWT token
    """
    expiration = datetime.now() + timedelta(seconds=JWT_EXPIRATION)
    
    payload = {
        "sub": user["username"],
        "exp": expiration.timestamp(),
        "iat": datetime.now().timestamp()
    }
    
    if "email" in user:
        payload["email"] = user["email"]
        
    if "full_name" in user:
        payload["name"] = user["full_name"]
        
    if "groups" in user:
        payload["groups"] = user["groups"]
        
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM) 