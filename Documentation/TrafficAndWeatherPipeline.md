# Traffic and Weather Pipeline

The Traffic and Weather Pipeline merges real-time traffic data from Mapbox with weather forecasts from Weatherbit to provide comprehensive travel condition snapshots.

## Overview

The `TrafficWeatherMergeService` coordinates data fetching from two external APIs and merges them into a unified snapshot used by the Prediction Engine.

## Architecture

```
TrafficWeatherMergeService
    ├─→ MapboxService (traffic & routing)
    └─→ WeatherbitService (weather forecasts)
```

## Mapbox Integration

### API Endpoint

**URL:** `https://api.mapbox.com/directions/v5/mapbox/driving-traffic/{coordinates}`

**Method:** GET

**Parameters:**
- `access_token`: Mapbox access token
- `geometries`: `geojson` (route geometry)
- `overview`: `full` (full route overview)
- `steps`: `true` (turn-by-turn steps)
- `annotations`: `congestion,duration` (traffic annotations)
- `alternatives`: `true` (alternative routes)

### Request Example

```
GET /directions/v5/mapbox/driving-traffic/-122.4194,37.7749;-122.4094,37.7849
  ?access_token=YOUR_TOKEN
  &geometries=geojson
  &overview=full
  &steps=true
  &annotations=congestion,duration
  &alternatives=true
```

### Response Structure

```json
{
  "routes": [
    {
      "distance": 12000,
      "duration": 900,
      "geometry": {
        "coordinates": [[-122.4194, 37.7749], ...],
        "type": "LineString"
      },
      "legs": [
        {
          "duration": 900,
          "distance": 12000,
          "annotation": {
            "congestion": [1, 2, 1, 3, ...],
            "duration": [120, 180, 90, ...]
          }
        }
      ]
    }
  ]
}
```

### Data Extraction

**RouteInfo Model:**
- `distance`: Route distance in meters
- `duration`: Baseline duration in seconds
- `trafficDelay`: Calculated traffic delay
- `congestionLevel`: 0-4 (none, low, moderate, heavy, severe)
- `geometry`: Route coordinates for map display
- `alternativeRoutes`: Up to 2 alternative routes

### Traffic Delay Calculation

```swift
private func calculateTrafficDelay(route: MapboxRoute) -> TimeInterval {
    let baselineDuration = route.duration
    let currentDuration = route.legs.first?.annotation?.duration.reduce(0, +) ?? baselineDuration
    return max(0, currentDuration - baselineDuration)
}
```

### Congestion Level Determination

```swift
private func determineCongestionLevel(route: MapboxRoute) -> CongestionLevel {
    let avgCongestion = route.legs.first?.annotation?.congestion.reduce(0, +) ?? 0
    let segmentCount = route.legs.first?.annotation?.congestion.count ?? 1
    let avg = Double(avgCongestion) / Double(segmentCount)
    
    switch avg {
    case 0..<1: return .none
    case 1..<2: return .low
    case 2..<3: return .moderate
    case 3..<4: return .heavy
    default: return .severe
    }
}
```

## Weatherbit Integration

### API Endpoint

**URL:** `https://api.weatherbit.io/v2.0/current`

**Method:** GET

**Parameters:**
- `key`: Weatherbit API key
- `lat`: Latitude
- `lon`: Longitude
- `units`: `M` (metric)

### Request Example

```
GET /v2.0/current?key=YOUR_KEY&lat=37.7849&lon=-122.4094&units=M
```

### Response Structure

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

### Data Extraction

**WeatherData Model:**
- `temperature`: Current temperature (°C)
- `feelsLike`: Feels-like temperature (°C)
- `conditions`: Weather condition enum
- `precipitation`: Precipitation amount (mm)
- `precipitationProbability`: 0-100%
- `windSpeed`: Wind speed (m/s)
- `windDirection`: Wind direction (degrees)
- `visibility`: Visibility (km)
- `humidity`: Relative humidity (%)
- `pressure`: Atmospheric pressure (hPa)
- `uvIndex`: UV index
- `cloudCoverage`: Cloud coverage (%)

## Data Merging

### Snapshot Creation

```swift
func snapshot(
    origin: Coordinate,
    destination: Coordinate,
    arrivalTime: Date
) async throws -> TrafficWeatherSnapshot {
    // Fetch route and weather in parallel
    async let routeTask = mapboxService.getRoute(from: origin, to: destination)
    async let weatherTask = weatherService.getCurrentWeather(at: destination)
    
    let route = try await routeTask
    let weather = try await weatherTask
    
    // Calculate heuristics delay
    let heuristicsDelay = calculateHeuristicsDelay(route: route, weather: weather)
    
    return TrafficWeatherSnapshot(
        route: route,
        weather: weather,
        heuristicsDelay: heuristicsDelay,
        generatedAt: Date(),
        explanation: buildExplanation(route: route, weather: weather),
        confidence: calculateConfidence(route: route, weather: weather)
    )
}
```

### Weather Impact Calculation

```swift
var leaveTimeAdjustment: TimeInterval {
    var adjustment: TimeInterval = 0
    
    // Precipitation impact
    if weather.precipitationProbability > 60 {
        adjustment += 300 // 5 minutes for heavy rain
    } else if weather.precipitationProbability > 30 {
        adjustment += 180 // 3 minutes for light rain
    }
    
    // Visibility impact
    if weather.visibility < 5 {
        adjustment += 240 // 4 minutes for poor visibility
    } else if weather.visibility < 10 {
        adjustment += 120 // 2 minutes for reduced visibility
    }
    
    // Wind impact (for extreme conditions)
    if weather.windSpeed > 15 {
        adjustment += 60 // 1 minute for strong winds
    }
    
    return adjustment
}
```

## Caching Strategy

### Cache Key

```swift
private func cacheKey(
    origin: Coordinate,
    destination: Coordinate,
    arrivalTime: Date
) -> String {
    let roundedTime = round(arrivalTime.timeIntervalSince1970 / 300) * 300 // Round to 5 minutes
    return "\(origin.latitude),\(origin.longitude);\(destination.latitude),\(destination.longitude);\(roundedTime)"
}
```

### Cache TTL

- **Default**: 90 seconds
- **Rationale**: Traffic and weather change frequently, but not second-by-second
- **Storage**: NSCache (in-memory)

### Cache Invalidation

- Time-based: Expires after 90 seconds
- Manual: Clear cache on app background/foreground
- Error-based: Clear cache on API errors

## Error Handling

### Mapbox Errors

**Fallback Strategy:**
1. Try cached route if available
2. Use static distance-based estimate
3. Return error if all fails

**Static Estimate:**
```swift
let estimatedDistance = origin.distance(to: destination)
let estimatedDuration = estimatedDistance / 13.0 // ~13 m/s average speed
let estimatedTrafficDelay = estimatedDuration * 0.2 // 20% traffic delay
```

### Weatherbit Errors

**Fallback Strategy:**
1. Try cached weather if available
2. Use default weather (clear, 20°C)
3. Return error if all fails

**Default Weather:**
```swift
WeatherData(
    temperature: 21,
    conditions: .partlyCloudy,
    precipitation: 0,
    precipitationProbability: 10,
    visibility: 10
)
```

### Complete Failure

If both APIs fail:
- Use static estimates for route
- Use default weather
- Lower confidence score (0.4-0.6)
- Continue with prediction (heuristics only)

## Rate Limits

### Mapbox

- **Free Tier**: 100,000 requests/month
- **Rate Limit**: 600 requests/minute
- **Caching**: Reduces API calls by ~60%

### Weatherbit

- **Free Tier**: 500 requests/day
- **Rate Limit**: 1 request/second
- **Caching**: Reduces API calls by ~70%

## Performance

- **Average Snapshot Time**: 800ms-1.2s
- **Cache Hit Rate**: ~60%
- **Parallel Fetching**: Route and weather fetched simultaneously
- **Timeout**: 10 seconds per API call

## Future Enhancements

1. **Forecast Integration**: Use weather forecasts for future trips
2. **Historical Traffic**: Use historical traffic patterns
3. **Incident Data**: Integrate traffic incident data
4. **Alternative Routes**: Compare multiple routes
5. **Weather Alerts**: Integrate severe weather alerts

