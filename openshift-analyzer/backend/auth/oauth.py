import os
import logging
import httpx
import json
from fastapi import APIRouter, Depends, HTTPException, Request, Response
from fastapi.security import OAuth2PasswordBearer, OAuth2AuthorizationCodeBearer
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from typing import Dict, Any, Optional
import jwt
from jose import JWTError, jwt as jose_jwt
from utils.config import load_config

router = APIRouter()
logger = logging.getLogger("openshift-analyzer")

# Load configuration
config_path = os.environ.get("CONFIG_PATH", "/app/config/config.yaml")
app_config = load_config(config_path)
oauth_config = app_config.get("auth", {}).get("oauth", {})

# Models
class Token(BaseModel):
    access_token: str
    token_type: str
    expires_in: int
    refresh_token: Optional[str] = None

class User(BaseModel):
    username: str
    email: Optional[str] = None
    full_name: Optional[str] = None
    groups: Optional[list] = None

# OAuth configuration from environment variables
CLIENT_ID = os.environ.get("OAUTH_CLIENT_ID", oauth_config.get("client_id", ""))
CLIENT_SECRET = os.environ.get("OAUTH_CLIENT_SECRET", oauth_config.get("client_secret", ""))
REDIRECT_URI = os.environ.get("OAUTH_REDIRECT_URI", oauth_config.get("redirect_uri", ""))
OPENSHIFT_AUTH_URL = os.environ.get("OPENSHIFT_AUTH_URL", "")
OPENSHIFT_TOKEN_URL = os.environ.get("OPENSHIFT_TOKEN_URL", "")
OPENSHIFT_API_URL = os.environ.get("OPENSHIFT_API_URL", "")

# Configure OAuth2
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")

@router.get("/login")
async def login():
    """Redirect to OpenShift OAuth login"""
    if not OPENSHIFT_AUTH_URL:
        # Use default OpenShift OAuth URL if not specified
        auth_url = "/oauth/authorize"
    else:
        auth_url = OPENSHIFT_AUTH_URL
        
    params = {
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
        "response_type": "code",
        "scope": "user:info",
    }
    
    # Build query string
    query = "&".join([f"{k}={v}" for k, v in params.items()])
    login_url = f"{auth_url}?{query}"
    
    return RedirectResponse(url=login_url)

@router.get("/callback")
async def callback(code: str, request: Request):
    """Handle OAuth callback from OpenShift"""
    try:
        if not OPENSHIFT_TOKEN_URL:
            # Use default OpenShift token URL if not specified
            token_url = "/oauth/token"
        else:
            token_url = OPENSHIFT_TOKEN_URL
            
        # Exchange authorization code for tokens
        token_data = {
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "code": code,
            "redirect_uri": REDIRECT_URI,
            "grant_type": "authorization_code",
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(token_url, data=token_data)
            if response.status_code != 200:
                logger.error(f"Failed to get token: {response.text}")
                raise HTTPException(status_code=400, detail="Failed to get token")
                
            token_json = response.json()
            
            # Get user info from token
            user_info = await get_user_info(token_json["access_token"])
            
            # Create session with user info and tokens
            # This is a simplified version - in production, use secure cookies or session storage
            response = RedirectResponse(url="/")
            response.set_cookie(
                key="access_token",
                value=token_json["access_token"],
                httponly=True,
                secure=True,
                samesite="lax",
            )
            response.set_cookie(
                key="user_info",
                value=json.dumps(user_info),
                httponly=True,
                secure=True,
                samesite="lax",
            )
            
            return response
            
    except Exception as e:
        logger.error(f"OAuth callback error: {str(e)}")
        raise HTTPException(status_code=400, detail=f"OAuth callback error: {str(e)}")

@router.get("/token", response_model=Token)
async def get_token(request: Request):
    """Get current token from session"""
    access_token = request.cookies.get("access_token")
    if not access_token:
        raise HTTPException(status_code=401, detail="Not authenticated")
        
    # In a real application, you would validate the token here
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": 3600,  # Placeholder value
    }

@router.get("/user", response_model=User)
async def get_current_user(request: Request):
    """Get current user info from session"""
    user_info = request.cookies.get("user_info")
    if not user_info:
        raise HTTPException(status_code=401, detail="Not authenticated")
        
    return json.loads(user_info)

@router.get("/logout")
async def logout():
    """Logout and clear session"""
    response = RedirectResponse(url="/")
    response.delete_cookie("access_token")
    response.delete_cookie("user_info")
    return response

async def get_user_info(token: str) -> Dict[str, Any]:
    """Get user info from OpenShift API using token"""
    try:
        if not OPENSHIFT_API_URL:
            # Use default OpenShift API URL if not specified
            api_url = "/apis/user.openshift.io/v1/users/~"
        else:
            api_url = f"{OPENSHIFT_API_URL}/apis/user.openshift.io/v1/users/~"
            
        headers = {"Authorization": f"Bearer {token}"}
        
        async with httpx.AsyncClient() as client:
            response = await client.get(api_url, headers=headers)
            if response.status_code != 200:
                logger.error(f"Failed to get user info: {response.text}")
                raise HTTPException(status_code=400, detail="Failed to get user info")
                
            user_data = response.json()
            
            return {
                "username": user_data["metadata"]["name"],
                "full_name": user_data.get("fullName"),
                "groups": user_data.get("groups", []),
            }
            
    except Exception as e:
        logger.error(f"Get user info error: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Get user info error: {str(e)}")

async def verify_token(token: str = Depends(oauth2_scheme)):
    """Verify JWT token and extract claims"""
    try:
        # This would use the OpenShift public keys to validate the token
        # For now, we just decode the token without verification
        payload = jwt.decode(token, options={"verify_signature": False})
        return payload
    except JWTError:
        raise HTTPException(
            status_code=401,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        ) 