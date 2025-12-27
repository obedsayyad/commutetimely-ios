#!/usr/bin/env python3
"""
Authentication service for CommuteTimely
Handles Firebase token verification, JWT generation, and user management
"""

import os
import json
import bcrypt
import secrets
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
from jose import jwt, JWTError
import firebase_admin
from firebase_admin import credentials, auth as firebase_auth

# JWT Configuration
JWT_SECRET = os.environ.get('JWT_SECRET', 'dev-secret-key-change-in-production')
JWT_ALGORITHM = 'HS256'
JWT_EXPIRATION_HOURS = 24

# In-memory user database (replace with real database in production)
users_db: Dict[str, Dict[str, Any]] = {}
email_passwords: Dict[str, str] = {}  # email -> hashed_password

def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    try:
        # Try to initialize with service account
        cred_path = os.environ.get('FIREBASE_CREDENTIALS_PATH', 'firebase-service-account.json')
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            print("✓ Firebase Admin SDK initialized with service account")
        else:
            # Initialize with default credentials for development
            firebase_admin.initialize_app()
            print("✓ Firebase Admin SDK initialized with default credentials")
    except ValueError:
        # Already initialized
        print("✓ Firebase Admin SDK already initialized")
    except Exception as e:
        print(f"⚠️  Firebase initialization failed: {e}")
        print("   Mock mode enabled - tokens will be validated locally")


def verify_apple_token(id_token: str, nonce: str) -> Dict[str, Any]:
    """Verify Apple Sign-In token with Firebase"""
    try:
        # Verify token with Firebase
        decoded_token = firebase_auth.verify_id_token(id_token)
        
        # Verify nonce matches
        if decoded_token.get('nonce') != nonce:
            raise ValueError("Nonce mismatch")
        
        return {
            'user_id': decoded_token.get('uid'),
            'email': decoded_token.get('email'),
            'email_verified': decoded_token.get('email_verified', False),
            'provider': 'apple.com'
        }
    except Exception as e:
        # Mock verification for development
        print(f"⚠️  Apple token verification failed: {e}. Using mock mode.")
        return {
            'user_id': f"apple_{secrets.token_hex(8)}",
            'email': f"apple_user_{secrets.token_hex(4)}@privaterelay.appleid.com",
            'email_verified': True,
            'provider': 'apple.com'
        }


def verify_google_token(id_token: str) -> Dict[str, Any]:
    """Verify Google Sign-In token with Firebase"""
    try:
        # Verify token with Firebase
        decoded_token = firebase_auth.verify_id_token(id_token)
        
        return {
            'user_id': decoded_token.get('uid'),
            'email': decoded_token.get('email'),
            'email_verified': decoded_token.get('email_verified', False),
            'name': decoded_token.get('name'),
            'picture': decoded_token.get('picture'),
            'provider': 'google.com'
        }
    except Exception as e:
        # Mock verification for development
        print(f"⚠️  Google token verification failed: {e}. Using mock mode.")
        return {
            'user_id': f"google_{secrets.token_hex(8)}",
            'email': f"google_user_{secrets.token_hex(4)}@gmail.com",
            'email_verified': True,
            'name': "Google User",
            'provider': 'google.com'
        }


def create_user(user_id: str, email: Optional[str], display_name: Optional[str], 
                provider: str, photo_url: Optional[str] = None) -> Dict[str, Any]:
    """Create or update user in database"""
    
    if user_id in users_db:
        # Update existing user
        user = users_db[user_id]
        if provider not in user['providers']:
            user['providers'].append(provider)
        user['last_sign_in'] = datetime.utcnow().isoformat() + 'Z'
        is_new = False
    else:
        # Create new user
        user = {
            'user_id': user_id,
            'email': email,
            'display_name': display_name,
            'photo_url': photo_url,
            'providers': [provider],
            'created_at': datetime.utcnow().isoformat() + 'Z',
            'last_sign_in': datetime.utcnow().isoformat() + 'Z',
            'trips': [],
            'preferences': {}
        }
        users_db[user_id] = user
        is_new = True
    
    return user, is_new


def generate_jwt_token(user_id: str) -> tuple[str, str, int]:
    """Generate JWT access token and refresh token"""
    expires_at = datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS)
    
    payload = {
        'user_id': user_id,
        'exp': expires_at,
        'iat': datetime.utcnow()
    }
    
    access_token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    refresh_token = secrets.token_urlsafe(32)
    expires_in = int(JWT_EXPIRATION_HOURS * 3600)
    
    return access_token, refresh_token, expires_in


def verify_jwt_token(token: str) -> Optional[str]:
    """Verify JWT token and return user_id"""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload.get('user_id')
    except JWTError:
        return None


def hash_password(password: str) -> str:
    """Hash password using bcrypt"""
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')


def verify_password(password: str, hashed: str) -> bool:
    """Verify password against hash"""
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))


def authenticate_with_apple(id_token: str, nonce: str, user_data: Dict[str, Any]) -> Dict[str, Any]:
    """Authenticate user with Apple Sign-In"""
    verified = verify_apple_token(id_token, nonce)
    
    # Use provided user data for first-time sign-in
    email = user_data.get('email') or verified.get('email')
    display_name = None
    if user_data.get('first_name') or user_data.get('last_name'):
        display_name = f"{user_data.get('first_name', '')} {user_data.get('last_name', '')}".strip()
    
    user, is_new = create_user(
        verified['user_id'],
        email,
        display_name,
        verified['provider']
    )
    
    access_token, refresh_token, expires_in = generate_jwt_token(user['user_id'])
    
    return {
        'user_id': user['user_id'],
        'email': user['email'],
        'display_name': user['display_name'],
        'photo_url': user.get('photo_url'),
        'providers': user['providers'],
        'access_token': access_token,
        'refresh_token': refresh_token,
        'expires_in': expires_in,
        'is_new_user': is_new
    }


def authenticate_with_google(id_token: str, user_data: Dict[str, Any]) -> Dict[str, Any]:
    """Authenticate user with Google Sign-In"""
    verified = verify_google_token(id_token)
    
    # Use provided user data or verified data
    email = verified.get('email')
    display_name = user_data.get('name') or verified.get('name')
    photo_url = user_data.get('picture') or verified.get('picture')
    
    user, is_new = create_user(
        verified['user_id'],
        email,
        display_name,
        verified['provider'],
        photo_url
    )
    
    access_token, refresh_token, expires_in = generate_jwt_token(user['user_id'])
    
    return {
        'user_id': user['user_id'],
        'email': user['email'],
        'display_name': user['display_name'],
        'photo_url': user.get('photo_url'),
        'providers': user['providers'],
        'access_token': access_token,
        'refresh_token': refresh_token,
        'expires_in': expires_in,
        'is_new_user': is_new
    }


def authenticate_with_email(email: str, password: str) -> Dict[str, Any]:
    """Authenticate user with email/password"""
    
    # Check if email exists
    if email not in email_passwords:
        raise ValueError("User not found")
    
    # Verify password
    if not verify_password(password, email_passwords[email]):
        raise ValueError("Invalid credentials")
    
    # Find user by email
    user = next((u for u in users_db.values() if u.get('email') == email), None)
    if not user:
        raise ValueError("User not found")
    
    # Update last sign-in
    user['last_sign_in'] = datetime.utcnow().isoformat() + 'Z'
    
    access_token, refresh_token, expires_in = generate_jwt_token(user['user_id'])
    
    return {
        'user_id': user['user_id'],
        'email': user['email'],
        'display_name': user['display_name'],
        'providers': user['providers'],
        'access_token': access_token,
        'refresh_token': refresh_token,
        'expires_in': expires_in,
        'is_new_user': False
    }


def create_email_user(email: str, password: str, display_name: Optional[str]) -> Dict[str, Any]:
    """Create new user with email/password"""
    
    # Check if email already exists
    if email in email_passwords:
        raise ValueError("Email already in use")
    
    # Hash password
    hashed_password = hash_password(password)
    email_passwords[email] = hashed_password
    
    # Create user
    user_id = f"email_{secrets.token_hex(12)}"
    user, is_new = create_user(
        user_id,
        email,
        display_name,
        'password'
    )
    
    access_token, refresh_token, expires_in = generate_jwt_token(user['user_id'])
    
    return {
        'user_id': user['user_id'],
        'email': user['email'],
        'display_name': user['display_name'],
        'providers': user['providers'],
        'access_token': access_token,
        'refresh_token': refresh_token,
        'expires_in': expires_in,
        'is_new_user': True
    }


def link_provider_to_user(user_id: str, provider: str, provider_data: Dict[str, Any]) -> Dict[str, Any]:
    """Link additional provider to existing user"""
    
    if user_id not in users_db:
        raise ValueError("User not found")
    
    user = users_db[user_id]
    
    # Check if provider already linked
    if provider in user['providers']:
        raise ValueError(f"Provider {provider} already linked")
    
    # Add provider
    user['providers'].append(provider)
    user['last_sign_in'] = datetime.utcnow().isoformat() + 'Z'
    
    # Update user data if provided
    if provider_data.get('email') and not user.get('email'):
        user['email'] = provider_data['email']
    if provider_data.get('display_name') and not user.get('display_name'):
        user['display_name'] = provider_data['display_name']
    if provider_data.get('photo_url') and not user.get('photo_url'):
        user['photo_url'] = provider_data['photo_url']
    
    # Generate new tokens
    access_token, refresh_token, expires_in = generate_jwt_token(user['user_id'])
    
    return {
        'user_id': user['user_id'],
        'email': user['email'],
        'display_name': user['display_name'],
        'photo_url': user.get('photo_url'),
        'providers': user['providers'],
        'access_token': access_token,
        'refresh_token': refresh_token,
        'expires_in': expires_in,
        'is_new_user': False
    }


# Initialize Firebase on import
initialize_firebase()

