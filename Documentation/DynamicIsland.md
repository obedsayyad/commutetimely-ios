# Dynamic Island & Live Activities

CommuteTimely uses Live Activities and Dynamic Island to provide real-time commute updates directly on the Lock Screen and in the Dynamic Island (iPhone 14 Pro and later).

## Overview

Live Activities show ongoing commute information:
- Leave time countdown
- Destination name
- ETA and travel time
- Weather conditions
- Real-time updates every 30 seconds

## Architecture

### CommuteActivityManager

The `CommuteActivityManager` service manages all Live Activity lifecycle:

```swift
protocol CommuteActivityManagerProtocol {
    func startActivity(for trip: Trip, recommendation: LeaveTimeRecommendation, firstName: String?) async throws
    func updateActivity(for tripId: UUID, recommendation: LeaveTimeRecommendation, firstName: String?) async
    func endActivity(for tripId: UUID) async
    func endAllActivities() async
    func isActivityActive(for tripId: UUID) async -> Bool
    func areActivitiesEnabled() async -> Bool
}
```

## Activity Attributes

### CommuteActivityAttributes

```swift
struct CommuteActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let leaveTime: Date
        let destinationAddress: String
        let travelTimeMinutes: Int
        let weatherCondition: String
        let confidence: Double
        let firstName: String?
    }
    
    let tripId: String
    let destinationAddress: String
}
```

## Activity States

### Compact View (Dynamic Island)

**Left Side:**
- Small icon (map pin)
- Leave time countdown (e.g., "15m")

**Right Side:**
- Destination name (truncated)

### Minimal View (Dynamic Island)

**Content:**
- Destination name
- Leave time (e.g., "Leave by 8:15 AM")

### Expanded View (Dynamic Island / Lock Screen)

**Full Details:**
- Destination address
- Leave time with countdown
- Travel time estimate
- Weather condition
- Confidence score
- Personalized greeting (if firstName available)

## Starting an Activity

### Flow

```
1. User saves trip
   ↓
2. LeaveTimeScheduler.scheduleTrip()
   ↓
3. PredictionEngine.recommendation() → Get leave time
   ↓
4. CommuteActivityManager.startActivity()
   ├─→ Check if Live Activities enabled
   ├─→ Create CommuteActivityAttributes
   ├─→ Build ActivityContent
   └─→ Activity.request() → ActivityKit
   ↓
5. Live Activity appears in Dynamic Island
```

### Code Example

```swift
let attributes = CommuteActivityAttributes(
    tripId: trip.id.uuidString,
    destinationAddress: trip.destination.address
)

let contentState = CommuteActivityAttributes.ContentState(
    leaveTime: recommendation.recommendedLeaveTimeUtc,
    destinationAddress: trip.destination.address,
    travelTimeMinutes: Int(recommendation.snapshot.route.totalDurationWithTraffic / 60),
    weatherCondition: recommendation.snapshot.weather.conditions.description,
    confidence: recommendation.prediction.confidence,
    firstName: firstName
)

let activityContent = ActivityContent(
    state: contentState,
    staleDate: Date().addingTimeInterval(300) // 5 minutes
)

let activity = try Activity<CommuteActivityAttributes>.request(
    attributes: attributes,
    content: activityContent,
    pushType: .token // For remote updates (future)
)
```

## Updating an Activity

### Throttling

Updates are throttled to prevent excessive API calls:

```swift
private let throttler = Throttler(interval: 30) // 30 seconds minimum
```

### Update Flow

```
1. Background task fires or user opens app
   ↓
2. LeaveTimeScheduler updates prediction
   ↓
3. CommuteActivityManager.updateActivity()
   ├─→ Check throttler (30-second minimum)
   ├─→ Build new ContentState
   └─→ Activity.update() → ActivityKit
   ↓
4. Dynamic Island updates with new data
```

### Code Example

```swift
func updateActivity(
    for tripId: UUID,
    recommendation: LeaveTimeRecommendation,
    firstName: String?
) async {
    await throttler.throttle {
        guard let activity = Activity<CommuteActivityAttributes>.activities.first(where: { $0.attributes.tripId == tripId.uuidString }) else {
            return
        }
        
        let contentState = buildContentState(
            trip: trip,
            recommendation: recommendation,
            firstName: firstName
        )
        
        let activityContent = ActivityContent(
            state: contentState,
            staleDate: Date().addingTimeInterval(300)
        )
        
        await activity.update(activityContent)
    }
}
```

## Ending an Activity

### Automatic End

Activities end automatically when:
- Trip arrival time passes
- User cancels trip
- Trip is deleted

### Manual End

```swift
func endActivity(for tripId: UUID) async {
    guard let activity = Activity<CommuteActivityAttributes>.activities.first(where: { $0.attributes.tripId == tripId.uuidString }) else {
        return
    }
    
    await activity.end(dismissalPolicy: .immediate)
}
```

## Content State Building

### Building Content State

```swift
private func buildContentState(
    trip: Trip,
    recommendation: LeaveTimeRecommendation,
    firstName: String?
) -> CommuteActivityAttributes.ContentState {
    let travelTimeMinutes = Int(recommendation.snapshot.route.totalDurationWithTraffic / 60)
    let weatherCondition = recommendation.snapshot.weather.conditions.description
    
    return CommuteActivityAttributes.ContentState(
        leaveTime: recommendation.recommendedLeaveTimeUtc,
        destinationAddress: trip.destination.address,
        travelTimeMinutes: travelTimeMinutes,
        weatherCondition: weatherCondition,
        confidence: recommendation.prediction.confidence,
        firstName: firstName
    )
}
```

## Permissions

### Checking Availability

```swift
func areActivitiesEnabled() async -> Bool {
    if #available(iOS 16.1, *) {
        #if canImport(ActivityKit)
        return ActivityAuthorizationInfo().areActivitiesEnabled
        #else
        return false
        #endif
    }
    return false
}
```

### Requesting Permission

Live Activities permission is requested automatically when starting an activity. If denied, the activity will fail with `CommuteActivityError.activitiesDisabled`.

## Error Handling

### Error Types

```swift
enum CommuteActivityError: Error {
    case notSupported // iOS < 16.1
    case activitiesDisabled // User disabled Live Activities
    case startFailed(Error) // Failed to start activity
    case updateFailed(Error) // Failed to update activity
}
```

### Error Recovery

- If activity fails to start: Log error, continue without Live Activity
- If update fails: Retry on next update cycle
- If activities disabled: Show message in Settings

## Battery Optimization

### Throttling

- Updates throttled to 30-second minimum
- Prevents excessive background work
- Reduces battery drain

### Stale Date

- Activities marked stale after 5 minutes
- System can dismiss stale activities
- Prevents showing outdated information

### Background Updates

- Updates only when app is active or background task fires
- No continuous polling
- Efficient resource usage

## Widget Extension (Future)

A widget extension can be added to show commute information on the Home Screen:

- **Small Widget**: Leave time countdown
- **Medium Widget**: Destination + leave time + weather
- **Large Widget**: Full commute details

## Platform Support

- **iOS 16.1+**: Live Activities support
- **iPhone 14 Pro+**: Dynamic Island support
- **Other Devices**: Lock Screen Live Activities only

## Settings Integration

Users can toggle Dynamic Island in Settings:

```swift
@Published var dynamicIslandEnabled: Bool {
    didSet {
        userPreferencesService.updateDynamicIslandEnabled(dynamicIslandEnabled)
    }
}
```

## Future Enhancements

1. **Remote Updates**: Use push tokens for server-driven updates
2. **Interactive Actions**: Tap to open app, cancel trip
3. **Multiple Activities**: Support multiple active trips
4. **Widget Extension**: Home Screen widgets
5. **Watch App**: Apple Watch complications

