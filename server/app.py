#!/usr/bin/env python3
"""
CommuteTimely Server
Flask-based REST API for ML leave-time predictions, auth, and cloud sync
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime, timedelta
from functools import wraps
import math
from typing import Dict, Any, Optional
import auth_service

app = Flask(__name__)
CORS(app)  # Enable CORS for iOS app

# Configuration
app.config['JSON_SORT_KEYS'] = False


# MARK: - Auth Middleware

def require_auth(f):
    """Decorator to require authentication for endpoints"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Missing or invalid authorization header'}), 401
        
        token = auth_header.split(' ')[1]
        user_id = auth_service.verify_jwt_token(token)
        
        if not user_id:
            return jsonify({'error': 'Invalid or expired token'}), 401
        
        # Add user_id to request context
        request.user_id = user_id
        return f(*args, **kwargs)
    
    return decorated_function


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'service': 'CommuteTimely Prediction API',
        'version': '1.0.0'
    })


@app.route('/predict', methods=['POST'])
def predict():
    """
    Main prediction endpoint
    
    Accepts trip details and returns recommended leave time with confidence score
    """
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['origin', 'destination', 'arrival_time', 'route_features', 'weather_features']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        # Extract features
        route = data['route_features']
        weather = data['weather_features']
        arrival_time = datetime.fromisoformat(data['arrival_time'].replace('Z', '+00:00'))
        current_time = datetime.fromisoformat(data.get('current_time', datetime.utcnow().isoformat()).replace('Z', '+00:00'))
        
        # Calculate prediction
        prediction = calculate_leave_time(
            arrival_time=arrival_time,
            current_time=current_time,
            distance=route['distance'],
            baseline_duration=route['baseline_duration'],
            traffic_delay=route['current_traffic_delay'],
            incident_count=route['incident_count'],
            congestion_level=route['congestion_level'],
            weather_score=weather['weather_score'],
            precipitation_prob=weather['precipitation_probability'],
            visibility=weather['visibility']
        )
        
        return jsonify(prediction), 200
        
    except KeyError as e:
        return jsonify({'error': f'Invalid data format: {str(e)}'}), 400
    except Exception as e:
        return jsonify({'error': f'Internal server error: {str(e)}'}), 500


def calculate_leave_time(
    arrival_time: datetime,
    current_time: datetime,
    distance: float,
    baseline_duration: float,
    traffic_delay: float,
    incident_count: int,
    congestion_level: int,
    weather_score: float,
    precipitation_prob: float,
    visibility: float
) -> Dict[str, Any]:
    """
    Calculate recommended leave time using heuristic model
    
    Args:
        arrival_time: Target arrival datetime
        current_time: Current datetime
        distance: Route distance in meters
        baseline_duration: Normal travel time in seconds
        traffic_delay: Current traffic delay in seconds
        incident_count: Number of traffic incidents
        congestion_level: Traffic congestion (0-4)
        weather_score: Weather quality score (0-100)
        precipitation_prob: Precipitation probability (0-100)
        visibility: Visibility in km
    
    Returns:
        Prediction dictionary with leave time, confidence, and explanation
    """
    
    # Start with baseline + current traffic
    travel_time = baseline_duration + traffic_delay
    
    # Weather adjustment
    weather_multiplier = 1.0
    if precipitation_prob > 60:
        weather_multiplier += 0.15
    elif precipitation_prob > 30:
        weather_multiplier += 0.08
    
    if visibility < 5:
        weather_multiplier += 0.10
    elif visibility < 10:
        weather_multiplier += 0.05
    
    travel_time *= weather_multiplier
    
    # Congestion adjustment
    congestion_multipliers = [1.0, 1.05, 1.15, 1.30, 1.50]
    travel_time *= congestion_multipliers[min(congestion_level, 4)]
    
    # Incident adjustment
    travel_time += incident_count * 120  # 2 minutes per incident
    
    # Calculate buffer based on variability
    base_buffer = 300  # 5 minutes base
    variability_buffer = travel_time * 0.15  # 15% of travel time
    
    # Increase buffer for uncertain conditions
    if congestion_level >= 3:
        variability_buffer *= 1.5
    if precipitation_prob > 50:
        variability_buffer *= 1.3
    
    buffer_seconds = base_buffer + variability_buffer
    buffer_minutes = int(buffer_seconds / 60)
    
    # Total time needed
    total_time_needed = travel_time + buffer_seconds
    
    # Calculate leave time
    leave_time = arrival_time - timedelta(seconds=total_time_needed)
    
    # Calculate confidence
    confidence = calculate_confidence(
        congestion_level=congestion_level,
        weather_score=weather_score,
        precipitation_prob=precipitation_prob,
        incident_count=incident_count,
        time_until_arrival=(arrival_time - current_time).total_seconds()
    )
    
    # Generate explanation
    explanation = generate_explanation(
        travel_time=travel_time,
        buffer_minutes=buffer_minutes,
        congestion_level=congestion_level,
        weather_score=weather_score,
        precipitation_prob=precipitation_prob
    )
    
    # Generate alternative leave times
    alternatives = [
        {
            'leave_time': (leave_time - timedelta(minutes=10)).isoformat() + 'Z',
            'arrival_probability': min(0.98, confidence + 0.15),
            'description': 'Extra safe: arrive 10 minutes early'
        },
        {
            'leave_time': (leave_time - timedelta(minutes=5)).isoformat() + 'Z',
            'arrival_probability': min(0.95, confidence + 0.08),
            'description': 'Safe: arrive 5 minutes early'
        },
        {
            'leave_time': (leave_time + timedelta(minutes=5)).isoformat() + 'Z',
            'arrival_probability': max(0.50, confidence - 0.20),
            'description': 'Risky: might arrive 5 minutes late'
        }
    ]
    
    return {
        'leave_time': leave_time.isoformat() + 'Z',
        'confidence': round(confidence, 2),
        'explanation': explanation,
        'alternative_leaves_times': alternatives,
        'buffer_minutes': buffer_minutes,
        'calculated_at': current_time.isoformat() + 'Z'
    }


def calculate_confidence(
    congestion_level: int,
    weather_score: float,
    precipitation_prob: float,
    incident_count: int,
    time_until_arrival: float
) -> float:
    """Calculate prediction confidence score (0.0 to 1.0)"""
    
    confidence = 0.85  # Base confidence
    
    # Reduce confidence for congestion
    congestion_penalties = [0, 0.05, 0.10, 0.15, 0.25]
    confidence -= congestion_penalties[min(congestion_level, 4)]
    
    # Reduce confidence for bad weather
    if weather_score < 50:
        confidence -= 0.15
    elif weather_score < 70:
        confidence -= 0.08
    
    # Reduce confidence for precipitation
    if precipitation_prob > 70:
        confidence -= 0.10
    elif precipitation_prob > 40:
        confidence -= 0.05
    
    # Reduce confidence for incidents
    confidence -= min(0.15, incident_count * 0.03)
    
    # Reduce confidence for predictions far in the future
    hours_until = time_until_arrival / 3600
    if hours_until > 4:
        confidence -= 0.10
    elif hours_until > 2:
        confidence -= 0.05
    
    return max(0.40, min(0.98, confidence))


def generate_explanation(
    travel_time: float,
    buffer_minutes: int,
    congestion_level: int,
    weather_score: float,
    precipitation_prob: float
) -> str:
    """Generate human-readable explanation"""
    
    parts = []
    
    # Travel time
    travel_mins = int(travel_time / 60)
    parts.append(f"{travel_mins} min travel")
    
    # Traffic
    traffic_descriptions = ["clear roads", "light traffic", "moderate traffic", "heavy traffic", "severe traffic"]
    if congestion_level > 0:
        parts.append(traffic_descriptions[min(congestion_level, 4)])
    
    # Weather
    if precipitation_prob > 50:
        parts.append("rain expected")
    elif weather_score < 70:
        parts.append("poor weather")
    
    # Buffer
    parts.append(f"{buffer_minutes} min buffer")
    
    return ", ".join(parts)




# MARK: - Authentication Endpoints

@app.route('/auth/apple', methods=['POST'])
def auth_apple():
    """Exchange Apple identity token for app access token"""
    try:
        data = request.get_json()
        id_token = data.get('id_token')
        nonce = data.get('nonce')
        user_data = data.get('user', {})
        
        if not id_token or not nonce:
            return jsonify({'error': 'Missing id_token or nonce'}), 400
        
        result = auth_service.authenticate_with_apple(id_token, nonce, user_data)
        return jsonify(result), 200
        
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        return jsonify({'error': f'Authentication failed: {str(e)}'}), 500


@app.route('/auth/google', methods=['POST'])
def auth_google():
    """Exchange Google ID token for app access token"""
    try:
        data = request.get_json()
        id_token = data.get('id_token')
        user_data = data.get('user', {})
        
        if not id_token:
            return jsonify({'error': 'Missing id_token'}), 400
        
        result = auth_service.authenticate_with_google(id_token, user_data)
        return jsonify(result), 200
        
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        return jsonify({'error': f'Authentication failed: {str(e)}'}), 500


@app.route('/auth/email/signup', methods=['POST'])
def auth_email_signup():
    """Create new account with email/password"""
    try:
        data = request.get_json()
        email = data.get('email')
        password = data.get('password')
        display_name = data.get('display_name')
        
        if not email or not password:
            return jsonify({'error': 'Missing email or password'}), 400
        
        result = auth_service.create_email_user(email, password, display_name)
        return jsonify(result), 201
        
    except ValueError as e:
        if 'already in use' in str(e):
            return jsonify({'error': str(e)}), 409
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        return jsonify({'error': f'Signup failed: {str(e)}'}), 500


@app.route('/auth/email/signin', methods=['POST'])
def auth_email_signin():
    """Sign in with email/password"""
    try:
        data = request.get_json()
        email = data.get('email')
        password = data.get('password')
        
        if not email or not password:
            return jsonify({'error': 'Missing email or password'}), 400
        
        result = auth_service.authenticate_with_email(email, password)
        return jsonify(result), 200
        
    except ValueError as e:
        if 'not found' in str(e):
            return jsonify({'error': str(e)}), 404
        return jsonify({'error': str(e)}), 401
    except Exception as e:
        return jsonify({'error': f'Sign-in failed: {str(e)}'}), 500


@app.route('/auth/link', methods=['POST'])
@require_auth
def auth_link():
    """Link additional provider to existing account"""
    try:
        data = request.get_json()
        provider = data.get('provider')
        
        if not provider:
            return jsonify({'error': 'Missing provider'}), 400
        
        user_id = request.user_id
        provider_data = {}
        
        if provider == 'apple':
            id_token = data.get('id_token')
            nonce = data.get('nonce')
            if not id_token or not nonce:
                return jsonify({'error': 'Missing id_token or nonce'}), 400
            
            verified = auth_service.verify_apple_token(id_token, nonce)
            provider_data = data.get('user', {})
            
        elif provider == 'google':
            id_token = data.get('id_token')
            if not id_token:
                return jsonify({'error': 'Missing id_token'}), 400
            
            verified = auth_service.verify_google_token(id_token)
            provider_data = data.get('user', {})
            
        elif provider == 'password':
            email = data.get('email')
            password = data.get('password')
            if not email or not password:
                return jsonify({'error': 'Missing email or password'}), 400
            
            # Check if email already exists
            if email in auth_service.email_passwords:
                return jsonify({'error': 'Email already in use'}), 409
            
            # Hash and store password
            hashed_password = auth_service.hash_password(password)
            auth_service.email_passwords[email] = hashed_password
            provider_data = {'email': email}
        else:
            return jsonify({'error': f'Unknown provider: {provider}'}), 400
        
        result = auth_service.link_provider_to_user(user_id, provider, provider_data)
        return jsonify(result), 200
        
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        return jsonify({'error': f'Linking failed: {str(e)}'}), 500


@app.route('/auth/me', methods=['GET'])
@require_auth
def auth_me():
    """Get current user profile"""
    try:
        user_id = request.user_id
        user = auth_service.users_db.get(user_id)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        return jsonify({
            'user_id': user['user_id'],
            'email': user.get('email'),
            'display_name': user.get('display_name'),
            'photo_url': user.get('photo_url'),
            'providers': user['providers'],
            'created_at': user['created_at'],
            'last_sign_in': user['last_sign_in']
        }), 200
        
    except Exception as e:
        return jsonify({'error': f'Failed to fetch user: {str(e)}'}), 500


# MARK: - Cloud Sync Endpoints

@app.route('/sync/trips', methods=['GET'])
@require_auth
def sync_get_trips():
    """Get user's synced trips"""
    try:
        user_id = request.user_id
        user = auth_service.users_db.get(user_id)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        return jsonify({
            'trips': user.get('trips', []),
            'synced_at': datetime.utcnow().isoformat() + 'Z'
        }), 200
        
    except Exception as e:
        return jsonify({'error': f'Failed to fetch trips: {str(e)}'}), 500


@app.route('/sync/trips', methods=['POST'])
@require_auth
def sync_save_trips():
    """Save/update user's trips"""
    try:
        user_id = request.user_id
        user = auth_service.users_db.get(user_id)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        data = request.get_json()
        trips = data.get('trips', [])
        
        # Merge trips (simple replace for now, could implement smarter merging)
        user['trips'] = trips
        
        return jsonify({
            'success': True,
            'trips_count': len(trips),
            'synced_at': datetime.utcnow().isoformat() + 'Z'
        }), 200
        
    except Exception as e:
        return jsonify({'error': f'Failed to save trips: {str(e)}'}), 500


@app.route('/sync/trips/<trip_id>', methods=['DELETE'])
@require_auth
def sync_delete_trip(trip_id):
    """Delete a specific trip"""
    try:
        user_id = request.user_id
        user = auth_service.users_db.get(user_id)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Filter out the trip with matching ID
        user['trips'] = [t for t in user.get('trips', []) if t.get('id') != trip_id]
        
        return jsonify({
            'success': True,
            'deleted_id': trip_id
        }), 200
        
    except Exception as e:
        return jsonify({'error': f'Failed to delete trip: {str(e)}'}), 500


@app.route('/sync/preferences', methods=['GET'])
@require_auth
def sync_get_preferences():
    """Get user's synced preferences"""
    try:
        user_id = request.user_id
        user = auth_service.users_db.get(user_id)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        return jsonify({
            'preferences': user.get('preferences', {}),
            'synced_at': datetime.utcnow().isoformat() + 'Z'
        }), 200
        
    except Exception as e:
        return jsonify({'error': f'Failed to fetch preferences: {str(e)}'}), 500


@app.route('/sync/preferences', methods=['PUT'])
@require_auth
def sync_update_preferences():
    """Update user's preferences"""
    try:
        user_id = request.user_id
        user = auth_service.users_db.get(user_id)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        data = request.get_json()
        preferences = data.get('preferences', {})
        
        # Update preferences
        user['preferences'] = preferences
        
        return jsonify({
            'success': True,
            'synced_at': datetime.utcnow().isoformat() + 'Z'
        }), 200
        
    except Exception as e:
        return jsonify({'error': f'Failed to update preferences: {str(e)}'}), 500


if __name__ == '__main__':
    print("=" * 60)
    print("CommuteTimely Server (Prediction + Auth + Sync)")
    print("=" * 60)
    print("Server starting on http://localhost:5000")
    print("")
    print("Endpoints:")
    print("  Health:")
    print("    GET  /health  - Health check")
    print("")
    print("  Prediction:")
    print("    POST /predict - Get leave time prediction")
    print("")
    print("  Authentication:")
    print("    POST /auth/apple          - Sign in with Apple")
    print("    POST /auth/google         - Sign in with Google")
    print("    POST /auth/email/signup   - Sign up with email")
    print("    POST /auth/email/signin   - Sign in with email")
    print("    POST /auth/link           - Link provider (requires auth)")
    print("    GET  /auth/me             - Get user profile (requires auth)")
    print("")
    print("  Cloud Sync:")
    print("    GET    /sync/trips          - Get synced trips (requires auth)")
    print("    POST   /sync/trips          - Save trips (requires auth)")
    print("    DELETE /sync/trips/:id      - Delete trip (requires auth)")
    print("    GET    /sync/preferences    - Get preferences (requires auth)")
    print("    PUT    /sync/preferences    - Update preferences (requires auth)")
    print("=" * 60)
    
    app.run(host='0.0.0.0', port=5000, debug=True)

