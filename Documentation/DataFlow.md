# Data Flow

This document describes the data flow through the CommuteTimely app for key user journeys.

## User Journey: Creating a Trip

```
1. User opens TripPlannerView
   ↓
2. User searches for destination
   ├─→ SearchService.search() → Apple Maps Search
   └─→ Results displayed in DestinationSearchView
   ↓
3. User selects destination
   ├─→ TripPlannerViewModel.selectedDestination = location
   └─→ UI updates to show selected destination
   ↓
4. User sets arrival time
   ├─→ TripPlannerViewModel.arrivalTime = date
   └─→ UI updates with time picker
   ↓
5. User taps "Get Prediction"
   ├─→ TripPlannerViewModel.fetchPrediction()
   │   ├─→ MapboxService.getRoute() → Mapbox API
   │   │   └─→ RouteInfo returned
   │   ├─→ WeatherService.getCurrentWeather() → Weatherbit API
   │   │   └─→ WeatherData returned
   │   └─→ MLPredictionService.predict() → Backend /predict
   │       └─→ Prediction returned
   └─→ UI displays leave time recommendation
   ↓
6. User saves trip
   ├─→ TripPlannerViewModel.saveTrip()
   │   ├─→ TripStorageService.saveTrip() → Local storage
   │   ├─→ LeaveTimeScheduler.scheduleTrip()
   │   │   ├─→ PredictionEngine.recommendation()
   │   │   └─→ LeaveTimeNotificationScheduler.schedule()
   │   └─→ AnalyticsService.trackEvent(.tripCreated)
   └─→ UI dismisses and returns to TripListView
```

## User Journey: Receiving Leave Time Notification

```
1. Background task fires (or scheduled notification)
   ↓
2. LeaveTimeScheduler.handleSignificantLocationChange()
   ├─→ Gets current location
   ├─→ Fetches active trips
   └─→ For each active trip:
       ├─→ PredictionEngine.recommendation()
       │   ├─→ TrafficWeatherMergeService.snapshot()
       │   │   ├─→ MapboxService.getRoute()
       │   │   └─→ WeatherService.getCurrentWeather()
       │   └─→ MLPredictionService.predict()
       └─→ LeaveTimeNotificationScheduler.reschedule()
           └─→ UNUserNotificationCenter.schedule()
   ↓
3. Notification fires at leave time
   ├─→ UNUserNotificationCenter delivers notification
   └─→ User sees notification
   ↓
4. User taps notification
   ├─→ App opens to TripListView
   └─→ Selected trip highlighted
```

## User Journey: Authentication

```
1. App launches
   ├─→ CommuteTimelyApp.init()
   │   └─→ Clerk.shared.configure()
   └─→ RootView observes authManager.authStatePublisher
   ↓
2. User signs in
   ├─→ AuthLandingView → Clerk sign-in UI
   ├─→ Clerk authenticates user
   └─→ authManager.authStatePublisher emits .signedIn(user)
   ↓
3. RootView handles auth state change
   ├─→ If signed in:
   │   ├─→ PersonalizedNotificationScheduler.scheduleDailyNotifications()
   │   └─→ Navigation updates to MainTabView
   └─→ If signed out:
       ├─→ PersonalizedNotificationScheduler.cancelAllPersonalizedNotifications()
       └─→ Navigation updates to OnboardingCoordinatorView
```

## User Journey: Dynamic Island / Live Activity

```
1. User saves trip with arrival time
   ↓
2. LeaveTimeScheduler.scheduleTrip()
   ├─→ PredictionEngine.recommendation() → Get leave time
   └─→ CommuteActivityManager.startActivity()
       ├─→ Creates CommuteActivityAttributes
       ├─→ Builds ActivityContent with leave time
       └─→ Activity.request() → ActivityKit
   ↓
3. Live Activity appears
   ├─→ Compact view in Dynamic Island
   ├─→ Minimal view in Dynamic Island
   └─→ Expanded view when tapped
   ↓
4. Background updates (every 30 seconds, throttled)
   ├─→ LeaveTimeScheduler updates prediction
   └─→ CommuteActivityManager.updateActivity()
       └─→ Activity.update() → ActivityKit
   ↓
5. Trip completes or user cancels
   └─→ CommuteActivityManager.endActivity()
       └─→ Activity.end() → ActivityKit
```

## Data Flow: Prediction Pipeline

```
User Input (origin, destination, arrival time)
    ↓
PredictionEngine.recommendation()
    ↓
┌─────────────────────────────────────┐
│ TrafficWeatherMergeService.snapshot() │
└─────────────────────────────────────┘
    ├─→ MapboxService.getRoute()
    │   └─→ HTTP GET → api.mapbox.com/directions/v5
    │       └─→ Response: RouteInfo (distance, duration, traffic)
    │
    └─→ WeatherService.getCurrentWeather()
        └─→ HTTP GET → api.weatherbit.io/v2.0/current
            └─→ Response: WeatherData (temp, conditions, precipitation)
    ↓
TrafficWeatherSnapshot (merged data)
    ↓
┌─────────────────────────────────────┐
│ MLPredictionService.predict()        │
└─────────────────────────────────────┘
    └─→ HTTP POST → Backend /predict
        ├─→ Request: { origin, destination, arrival_time, route_features, weather_features }
        └─→ Response: { leave_time, confidence, explanation }
    ↓
Prediction (leave time, confidence)
    ↓
LeaveTimeRecommendation
    ├─→ recommendedLeaveTimeUtc
    ├─→ weatherPenaltyMinutes
    ├─→ userBufferMinutes
    └─→ explanation
    ↓
UI Display / Notification Scheduling
```

## Data Flow: Cloud Sync

```
User saves trip locally
    ↓
TripStorageService.saveTrip()
    ├─→ Saves to local storage
    └─→ Triggers sync if authenticated
        ↓
CloudSyncService.syncTrip()
    ├─→ Gets auth token from AuthSessionController
    ├─→ HTTP POST → Backend /sync/trips
    │   └─→ Request: { trip: {...} }
    └─→ Response: { success: true }
    ↓
Trip synced to cloud
    ↓
Other devices fetch on launch
    ├─→ CloudSyncService.fetchTrips()
    │   └─→ HTTP GET → Backend /sync/trips
    └─→ Trips loaded into TripStorageService
```

## Data Flow: Personalized Notifications

```
User enables personalized notifications in Settings
    ↓
SettingsViewModel.updatePreferences()
    ├─→ UserPreferencesService.updatePreferences()
    └─→ PersonalizedNotificationScheduler.scheduleDailyNotifications()
        ├─→ Gets firstName from AuthSessionController
        ├─→ Gets current day index from UserPreferences
        └─→ Schedules 7 notifications (one per day)
            ├─→ Each notification uses unique message template
            └─→ Message includes user's firstName
    ↓
Notifications scheduled
    ↓
Notification fires (e.g., Monday 8:00 AM)
    ├─→ UNUserNotificationCenter delivers notification
    └─→ User sees: "Good morning, [FirstName] — This week starts strong..."
    ↓
User taps notification
    └─→ App opens to TripListView
```

## Caching Strategy

### TrafficWeatherMergeService Cache

- **Key**: `"\(origin.lat),\(origin.lon);\(dest.lat),\(dest.lon);\(arrivalTime)"`
- **TTL**: 90 seconds
- **Storage**: NSCache
- **Invalidation**: Time-based

### Destination Store Cache

- **Key**: Search query + proximity
- **TTL**: 5 minutes
- **Storage**: In-memory dictionary
- **Invalidation**: Time-based

### Route Cache (Mapbox)

- **Key**: Origin + Destination coordinates
- **TTL**: 5 minutes (handled by MapboxService)
- **Storage**: In-memory
- **Invalidation**: Time-based

## Error Handling Flow

```
Service call fails
    ↓
Error caught by ViewModel
    ├─→ If network error:
    │   └─→ Try cached data
    ├─→ If API error:
    │   └─→ Fallback to heuristics
    └─→ If all fails:
        └─→ ViewState.error → UI shows error message
    ↓
User sees error message
    ├─→ Option to retry
    └─→ Option to use cached/fallback data
```

