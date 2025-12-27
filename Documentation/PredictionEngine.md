# Prediction Engine

The Prediction Engine is the core intelligence system that calculates optimal leave times for trips by combining real-time traffic data, weather forecasts, and machine learning predictions.

## Overview

The `PredictionEngine` orchestrates the prediction flow:

1. Fetches traffic and weather data
2. Sends features to ML service
3. Applies user preferences (buffer time)
4. Calculates final leave time recommendation
5. Provides fallback heuristics if ML fails

## Architecture

```
PredictionEngine
    ├─→ TrafficWeatherMergeService (traffic + weather data)
    ├─→ MLPredictionService (ML predictions)
    └─→ UserPreferencesService (user buffer preferences)
```

## Inputs

### Required Inputs

- **origin**: `Coordinate` (latitude, longitude)
- **destination**: `Coordinate` (latitude, longitude)
- **arrivalTime**: `Date` (target arrival time in UTC)

### Data Sources

1. **Traffic Data** (from Mapbox):
   - Route distance
   - Baseline duration
   - Current traffic delay
   - Congestion level (0-4)
   - Alternative routes

2. **Weather Data** (from Weatherbit):
   - Temperature
   - Conditions (clear, cloudy, rain, etc.)
   - Precipitation probability
   - Visibility
   - Wind speed

3. **User Preferences**:
   - Default reminder offsets (buffer minutes)
   - Notification preferences

## Prediction Flow

### Step 1: Traffic & Weather Snapshot

```swift
let snapshot = try await trafficWeatherService.snapshot(
    origin: origin,
    destination: destination,
    arrivalTime: arrivalTime
)
```

**Returns:** `TrafficWeatherSnapshot`
- Route information with traffic
- Weather data
- Heuristics delay (fallback calculation)
- Confidence score

### Step 2: ML Prediction

```swift
let prediction = try await mlService.predict(
    origin: origin,
    destination: destination,
    arrivalTime: arrivalTime,
    routeInfo: snapshot.route,
    weather: snapshot.weather
)
```

**Returns:** `Prediction`
- Leave time (Date)
- Confidence (0.0-1.0)
- Explanation (String)
- Alternative leave times
- Prediction source (mlModel or coreML)

### Step 3: User Buffer Application

```swift
let preferences = await userPreferencesService.loadPreferences()
let userBufferMinutes = preferences.notificationSettings.defaultReminderOffsets.first ?? 10
```

### Step 4: Final Calculation

```swift
let baseTravelTime = snapshot.route.totalDurationWithTraffic
let weatherAdjustment = snapshot.leaveTimeAdjustment
let userBufferSeconds = Double(userBufferMinutes * 60)
let totalTravelTime = baseTravelTime + weatherAdjustment + userBufferSeconds

let recommendedLeaveTimeUtc = arrivalTime.addingTimeInterval(-totalTravelTime)
```

## Fallback Heuristics

If ML prediction fails, the engine uses heuristic calculations:

```swift
private func heuristicPrediction(
    snapshot: TrafficWeatherSnapshot,
    arrivalTime: Date
) -> Prediction {
    let travelTime = snapshot.route.totalDurationWithTraffic + snapshot.leaveTimeAdjustment
    let leaveTime = arrivalTime.addingTimeInterval(-travelTime)
    let bufferMinutes = Int(max(5, snapshot.leaveTimeAdjustment / 60))
    
    return Prediction(
        leaveTime: leaveTime,
        confidence: snapshot.confidence,
        explanation: snapshot.explanation,
        alternativeLeaveTimes: [...],
        bufferMinutes: bufferMinutes,
        predictionSource: .coreML,
        predictedAt: Date()
    )
}
```

## Output

### LeaveTimeRecommendation

```swift
struct LeaveTimeRecommendation {
    let prediction: Prediction
    let snapshot: TrafficWeatherSnapshot
    let source: PredictionSource
    let recommendedLeaveTimeUtc: Date
    let explanation: String
    let weatherPenaltyMinutes: Int
    let userBufferMinutes: Int
}
```

**Example Explanation:**
```
"45 min travel • moderate traffic • 5 min weather delay • 10 min buffer • Leave by 8:15 AM"
```

## Prediction Sources

### 1. ML Model (Preferred)

- Server-side ML prediction via `/predict` endpoint
- Uses historical patterns and advanced features
- Higher confidence scores
- Source: `PredictionSource.mlModel`

### 2. Core ML Heuristics (Fallback)

- On-device calculation
- Based on traffic + weather data only
- Lower confidence scores
- Source: `PredictionSource.coreML`

## Confidence Scoring

- **ML Model**: 0.75 - 0.95 (high confidence)
- **Heuristics**: 0.60 - 0.75 (medium confidence)
- **Cached Data**: 0.50 - 0.70 (lower confidence)

## Weather Impact Calculation

Weather adjustments are calculated in `TrafficWeatherMergeService`:

```swift
var leaveTimeAdjustment: TimeInterval {
    var adjustment: TimeInterval = 0
    
    // Precipitation impact
    if weather.precipitationProbability > 60 {
        adjustment += 300 // 5 minutes
    } else if weather.precipitationProbability > 30 {
        adjustment += 180 // 3 minutes
    }
    
    // Visibility impact
    if weather.visibility < 5 {
        adjustment += 240 // 4 minutes
    } else if weather.visibility < 10 {
        adjustment += 120 // 2 minutes
    }
    
    return adjustment
}
```

## Error Handling

### Network Errors

- Falls back to cached snapshot if available
- Uses heuristic prediction if no cache
- Returns error state to ViewModel

### ML Service Errors

- Falls back to heuristic prediction
- Logs error for debugging
- Continues with lower confidence

### Complete Failure

- Returns default snapshot with static estimates
- Uses distance-based heuristics
- Provides basic leave time recommendation

## Logging

Verbose logging (enabled via `PREDICTION_VERBOSE_LOGGING`):

```
[PredictionEngine]
Route: 12 mi, traffic moderate
Weather: partlyCloudy, 21°
Leave at: 2025-11-29 08:15:00 (confidence 85%)
Explanation: 45 min travel • moderate traffic • 5 min weather delay • 10 min buffer
```

## Performance

- **Average Prediction Time**: 1-2 seconds
- **Cache Hit Rate**: ~60% (90-second TTL)
- **ML Success Rate**: ~95% (5% fallback to heuristics)

## Future Enhancements

1. **Historical Pattern Learning**: Use past trip data to improve predictions
2. **Route Alternatives**: Consider multiple routes and select best
3. **Time-of-Day Patterns**: Learn user's typical commute times
4. **Weather Forecast Integration**: Use forecast data for future trips
5. **On-Device ML**: Core ML model for offline predictions

