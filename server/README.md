# CommuteTimely Mock Prediction Server

Flask-based REST API server that provides ML leave-time predictions for the CommuteTimely iOS app.

## Setup

### Requirements
- Python 3.8 or higher
- pip

### Installation

1. **Create a virtual environment** (recommended):
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. **Install dependencies**:
```bash
pip install -r requirements.txt
```

## Running the Server

### Development Mode

```bash
python app.py
```

The server will start on `http://localhost:5000`.

### Production Mode

For production, use a WSGI server like Gunicorn:

```bash
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 app:app
```

## API Endpoints

### Health Check

**GET** `/health`

Returns server health status.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-11-24T10:30:00Z",
  "service": "CommuteTimely Prediction API",
  "version": "1.0.0"
}
```

### Predict Leave Time

**POST** `/predict`

Calculate recommended leave time based on traffic, weather, and other factors.

**Request Body:**
```json
{
  "origin": {
    "latitude": 37.7749,
    "longitude": -122.4194
  },
  "destination": {
    "latitude": 37.8044,
    "longitude": -122.2712
  },
  "arrival_time": "2024-11-24T09:00:00Z",
  "current_time": "2024-11-24T08:00:00Z",
  "route_features": {
    "distance": 15000.0,
    "baseline_duration": 1200.0,
    "current_traffic_delay": 180.0,
    "incident_count": 1,
    "congestion_level": 2
  },
  "weather_features": {
    "temperature": 22.0,
    "precipitation": 0.0,
    "precipitation_probability": 20.0,
    "wind_speed": 5.5,
    "visibility": 10.0,
    "weather_score": 85.0
  },
  "user_features": {
    "user_id": "hashed_user_id",
    "historical_variance": 0.15,
    "preferred_buffer": 15
  }
}
```

**Response:**
```json
{
  "leave_time": "2024-11-24T08:35:00Z",
  "confidence": 0.85,
  "explanation": "25 min travel, moderate traffic, 10 min buffer",
  "alternative_leaves_times": [
    {
      "leave_time": "2024-11-24T08:25:00Z",
      "arrival_probability": 0.95,
      "description": "Extra safe: arrive 10 minutes early"
    },
    {
      "leave_time": "2024-11-24T08:30:00Z",
      "arrival_probability": 0.90,
      "description": "Safe: arrive 5 minutes early"
    },
    {
      "leave_time": "2024-11-24T08:40:00Z",
      "arrival_probability": 0.65,
      "description": "Risky: might arrive 5 minutes late"
    }
  ],
  "buffer_minutes": 10,
  "calculated_at": "2024-11-24T08:00:00Z"
}
```

## Prediction Algorithm

The mock server uses a heuristic-based model that considers:

1. **Base Travel Time**: Route baseline duration + current traffic delay
2. **Weather Impact**: Adjusts travel time based on precipitation and visibility
3. **Congestion Multiplier**: Applies traffic-based multipliers (1.0x to 1.5x)
4. **Incident Delays**: Adds ~2 minutes per reported incident
5. **Buffer Calculation**: 5 min base + 15% of travel time, adjusted for uncertainty
6. **Confidence Score**: Based on prediction reliability considering all factors

## Testing

### Using curl

```bash
# Health check
curl http://localhost:5000/health

# Prediction request
curl -X POST http://localhost:5000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "origin": {"latitude": 37.7749, "longitude": -122.4194},
    "destination": {"latitude": 37.8044, "longitude": -122.2712},
    "arrival_time": "2024-11-24T09:00:00Z",
    "current_time": "2024-11-24T08:00:00Z",
    "route_features": {
      "distance": 15000,
      "baseline_duration": 1200,
      "current_traffic_delay": 180,
      "incident_count": 1,
      "congestion_level": 2
    },
    "weather_features": {
      "temperature": 22,
      "precipitation": 0,
      "precipitation_probability": 20,
      "wind_speed": 5.5,
      "visibility": 10,
      "weather_score": 85
    }
  }'
```

### Using Python

```python
import requests
import json
from datetime import datetime, timedelta

url = "http://localhost:5000/predict"
arrival = datetime.now() + timedelta(hours=1)

payload = {
    "origin": {"latitude": 37.7749, "longitude": -122.4194},
    "destination": {"latitude": 37.8044, "longitude": -122.2712},
    "arrival_time": arrival.isoformat() + "Z",
    "current_time": datetime.now().isoformat() + "Z",
    "route_features": {
        "distance": 15000,
        "baseline_duration": 1200,
        "current_traffic_delay": 180,
        "incident_count": 1,
        "congestion_level": 2
    },
    "weather_features": {
        "temperature": 22,
        "precipitation": 0,
        "precipitation_probability": 20,
        "wind_speed": 5.5,
        "visibility": 10,
        "weather_score": 85
    }
}

response = requests.post(url, json=payload)
print(json.dumps(response.json(), indent=2))
```

## Deployment

For production deployment, consider:

1. **Use a production WSGI server** (Gunicorn, uWSGI)
2. **Add authentication** for API security
3. **Implement rate limiting** to prevent abuse
4. **Add logging and monitoring**
5. **Use environment variables** for configuration
6. **Deploy behind a reverse proxy** (nginx, Apache)

### Example Deployment (Heroku)

Create `Procfile`:
```
web: gunicorn app:app
```

Deploy:
```bash
heroku create commutetimely-api
git push heroku main
```

## Replacing with Real ML Model

To replace this mock with a real ML model:

1. Train your model using historical trip data
2. Save model weights (e.g., using joblib, pickle, or TensorFlow SavedModel)
3. Load the model in `app.py`:
   ```python
   import joblib
   model = joblib.load('leave_time_model.pkl')
   ```
4. Replace `calculate_leave_time()` with model inference:
   ```python
   features = prepare_features(data)
   prediction = model.predict(features)
   ```

## License

MIT License - See LICENSE file for details

