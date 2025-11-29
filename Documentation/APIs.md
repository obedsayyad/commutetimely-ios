# APIs

This document describes all API endpoints used by CommuteTimely, including the backend prediction server, Mapbox, Weatherbit, and Clerk.

## Backend Prediction Server

### Base URL

- **Development**: `http://localhost:5000`
- **Production**: Configured via `PREDICTION_SERVER_URL` in `Secrets.xcconfig`

### Endpoints

#### POST /predict

**Description:** Main prediction endpoint that calculates optimal leave time using ML model.

**Authentication:** Optional (Bearer token for authenticated users)

**Request Body:**
```json
{
  "origin": {
    "latitude": 37.7749,
    "longitude": -122.4194
  },
  "destination": {
    "latitude": 37.7849,
    "longitude": -122.4094
  },
  "arrival_time": "2025-11-29T10:00:00Z",
  "current_time": "2025-11-29T08:00:00Z",
  "route_features": {
    "distance": 12000,
    "baseline_duration": 900,
    "current_traffic_delay": 120,
    "incident_count": 0,
    "congestion_level": 2
  },
  "weather_features": {
    "weather_score": 85,
    "precipitation_probability": 10,
    "visibility": 10
  }
}
```

**Response (200 OK):**
```json
{
  "leave_time": "2025-11-29T08:15:00Z",
  "confidence": 0.85,
  "explanation": "45 min travel • moderate traffic • 5 min weather delay • 10 min buffer",
  "alternative_leave_times": [
    {
      "leave_time": "2025-11-29T08:05:00Z",
      "arrival_probability": 0.92,
      "description": "Leave 10 min earlier for extra buffer"
    },
    {
      "leave_time": "2025-11-29T08:20:00Z",
      "arrival_probability": 0.65,
      "description": "Cutting it close"
    }
  ],
  "buffer_minutes": 10,
  "prediction_source": "mlModel",
  "predicted_at": "2025-11-29T08:00:00Z"
}
```

**Error Responses:**

- **400 Bad Request**: Missing required fields
```json
{
  "error": "Missing required field: arrival_time"
}
```

- **500 Internal Server Error**: Server error
```json
{
  "error": "Internal server error: ..."
}
```

#### GET /health

**Description:** Health check endpoint.

**Response (200 OK):**
```json
{
  "status": "healthy",
  "timestamp": "2025-11-29T08:00:00Z",
  "service": "CommuteTimely Prediction API",
  "version": "1.0.0"
}
```

#### POST /sync/trips

**Description:** Sync trips to cloud (authenticated).

**Authentication:** Required (Bearer token)

**Request Body:**
```json
{
  "trip": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "destination": {
      "latitude": 37.7849,
      "longitude": -122.4094,
      "address": "123 Main St, San Francisco, CA"
    },
    "arrival_time": "2025-11-29T10:00:00Z",
    "buffer_minutes": 10,
    "repeat_days": [1, 2, 3, 4, 5],
    "is_active": true
  }
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "trip_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

#### GET /sync/trips

**Description:** Fetch synced trips (authenticated).

**Authentication:** Required (Bearer token)

**Response (200 OK):**
```json
{
  "trips": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "destination": {...},
      "arrival_time": "2025-11-29T10:00:00Z",
      "buffer_minutes": 10,
      "repeat_days": [1, 2, 3, 4, 5],
      "is_active": true
    }
  ]
}
```

## Mapbox API

### Base URL

`https://api.mapbox.com`

### Endpoints

#### GET /directions/v5/mapbox/driving-traffic/{coordinates}

**Description:** Get route with traffic data.

**Parameters:**
- `coordinates`: `{lon1},{lat1};{lon2},{lat2}` (origin;destination)
- `access_token`: Mapbox access token (required)
- `geometries`: `geojson` (route geometry format)
- `overview`: `full` (route overview level)
- `steps`: `true` (include turn-by-turn steps)
- `annotations`: `congestion,duration` (traffic annotations)
- `alternatives`: `true` (include alternative routes)

**Example Request:**
```
GET /directions/v5/mapbox/driving-traffic/-122.4194,37.7749;-122.4094,37.7849?access_token=YOUR_TOKEN&geometries=geojson&overview=full&steps=true&annotations=congestion,duration&alternatives=true
```

**Response:**
```json
{
  "routes": [
    {
      "distance": 12000,
      "duration": 900,
      "geometry": {
        "coordinates": [[-122.4194, 37.7749], [-122.4094, 37.7849]],
        "type": "LineString"
      },
      "legs": [
        {
          "duration": 900,
          "distance": 12000,
          "annotation": {
            "congestion": [1, 2, 1, 3, 2],
            "duration": [120, 180, 90, 240, 270]
          }
        }
      ]
    }
  ]
}
```

#### GET /geocoding/v5/mapbox.places/{query}.json

**Description:** Search for places.

**Parameters:**
- `query`: Search query (URL encoded)
- `access_token`: Mapbox access token (required)
- `limit`: `10` (max results)
- `types`: `address,poi` (result types)
- `proximity`: `{lon},{lat}` (optional, bias results)

**Example Request:**
```
GET /geocoding/v5/mapbox.places/coffee.json?access_token=YOUR_TOKEN&limit=10&types=address,poi&proximity=-122.4194,37.7749
```

**Response:**
```json
{
  "features": [
    {
      "id": "poi.123",
      "type": "Feature",
      "place_name": "Blue Bottle Coffee, 123 Main St, San Francisco, CA",
      "geometry": {
        "coordinates": [-122.4094, 37.7849]
      },
      "properties": {
        "address": "123 Main St"
      }
    }
  ]
}
```

### Rate Limits

- **Free Tier**: 100,000 requests/month
- **Rate Limit**: 600 requests/minute

## Weatherbit API

### Base URL

`https://api.weatherbit.io/v2.0`

### Endpoints

#### GET /current

**Description:** Get current weather conditions.

**Parameters:**
- `key`: Weatherbit API key (required)
- `lat`: Latitude
- `lon`: Longitude
- `units`: `M` (metric) or `I` (imperial)

**Example Request:**
```
GET /current?key=YOUR_KEY&lat=37.7849&lon=-122.4094&units=M
```

**Response:**
```json
{
  "data": [
    {
      "temp": 21.5,
      "feels_like": 20.8,
      "weather": {
        "code": 801,
        "description": "Few clouds"
      },
      "precip": 0,
      "precip_prob": 10,
      "wind_spd": 4.2,
      "wind_dir": 180,
      "vis": 10,
      "rh": 55,
      "pres": 1012.5,
      "uv": 4.2,
      "clouds": 20
    }
  ]
}
```

#### GET /forecast/daily

**Description:** Get daily weather forecast (future use).

**Parameters:**
- `key`: Weatherbit API key (required)
- `lat`: Latitude
- `lon`: Longitude
- `days`: Number of days (1-16)
- `units`: `M` (metric) or `I` (imperial)

### Rate Limits

- **Free Tier**: 500 requests/day
- **Rate Limit**: 1 request/second

## Clerk API

### Authentication

CommuteTimely uses Clerk iOS SDK for authentication. The SDK handles all API communication with Clerk.

### User Data

**User Object:**
```swift
struct ClerkUser {
    let id: String
    let firstName: String?
    let lastName: String?
    let emailAddresses: [EmailAddress]
    let imageUrl: String?
}
```

### Token Management

**ID Token:**
- Retrieved via `authManager.idToken()`
- Used for authenticated backend requests
- Automatically refreshed by Clerk SDK

**Usage:**
```swift
let token = try await authManager.idToken()
let headers = ["Authorization": "Bearer \(token)"]
```

## Error Handling

### Network Errors

All network requests handle errors consistently:

```swift
enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int, String)
    case unauthorized
    case rateLimited
}
```

### Retry Logic

- **Mapbox**: No automatic retry (use cache)
- **Weatherbit**: No automatic retry (use cache)
- **Backend**: Retry once on 5xx errors

### Fallback Behavior

- **Mapbox fails**: Use cached route or static estimate
- **Weatherbit fails**: Use cached weather or default weather
- **Backend fails**: Use heuristic prediction

## API Keys Configuration

All API keys are configured in `Secrets.xcconfig`:

```properties
MAPBOX_ACCESS_TOKEN = pk.eyJ1IjoiY29tbXV0ZXRpbWVseSIsImEiOiJjbWUzMzUydmcwMmN1MmtzZnoycGs1ZDhhIn0.438vHnYipmUNS7JoCglyMg
WEATHERBIT_API_KEY = 836afe5ccf9c46e1bc2fa3a894f676b3
PREDICTION_SERVER_URL = http://localhost:5000
CLERK_PUBLISHABLE_KEY = pk_test_...
```

## Testing

### Mock Server

A Flask mock server is provided in `server/app.py` for local testing:

```bash
cd server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py
```

Server runs on `http://localhost:5000`

### Testing Endpoints

```bash
# Health check
curl http://localhost:5000/health

# Prediction (example)
curl -X POST http://localhost:5000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "origin": {"latitude": 37.7749, "longitude": -122.4194},
    "destination": {"latitude": 37.7849, "longitude": -122.4094},
    "arrival_time": "2025-11-29T10:00:00Z",
    "route_features": {...},
    "weather_features": {...}
  }'
```

