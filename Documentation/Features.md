# Features

This document describes all major features in CommuteTimely.

## Core Features

### 1. Destination Selection

**Description:**
Users can search for and select destinations using Apple Maps search integration.

**User Flow:**
1. User taps search field in TripPlannerView
2. Types destination name or address
3. Search results appear as user types (debounced)
4. User selects destination from results
5. Destination is saved to trip

**Technical Details:**
- Uses `AppleMapsSearchService` for search
- Results cached for 5 minutes
- Search debounced to reduce API calls
- Proximity-based ranking when location available

**UI Components:**
- `DestinationSearchView`: Search interface
- `MapView`: Map display with pins

---

### 2. Real-time ETA & Weather Integration

**Description:**
App fetches real-time traffic data from Mapbox and weather forecasts from Weatherbit to calculate accurate travel times.

**User Flow:**
1. User selects destination and arrival time
2. Taps "Get Prediction"
3. App fetches:
   - Route from Mapbox (with traffic)
   - Weather from Weatherbit
   - ML prediction from backend
4. UI displays leave time recommendation

**Technical Details:**
- `TrafficWeatherMergeService` merges data from both APIs
- Caching: 90-second TTL for snapshots
- Fallback heuristics if APIs fail
- Weather impact calculated (precipitation, visibility)

**Data Sources:**
- Mapbox Directions API: Routing and traffic
- Weatherbit API: Current weather and forecasts

---

### 3. Leave-time Prediction

**Description:**
Machine learning model predicts optimal leave time based on traffic, weather, and historical patterns.

**User Flow:**
1. User creates trip with destination and arrival time
2. App calculates prediction:
   - Fetches traffic and weather data
   - Sends features to ML backend
   - Receives leave time with confidence score
3. UI displays:
   - Recommended leave time
   - Confidence percentage
   - Explanation (e.g., "45 min travel • 5 min weather delay • 10 min buffer")

**Technical Details:**
- `PredictionEngine` orchestrates prediction flow
- Server-side ML model at `/predict` endpoint
- Fallback to heuristics if ML fails
- User buffer preferences applied

**Prediction Sources:**
- `mlModel`: Server ML prediction (preferred)
- `coreML`: On-device heuristic (fallback)

---

### 4. Dynamic Island + Live Activities

**Description:**
Live Activities show real-time commute updates in Dynamic Island and Lock Screen.

**User Flow:**
1. User saves trip with arrival time
2. Live Activity automatically starts
3. Shows in Dynamic Island:
   - Compact: Leave time countdown
   - Minimal: Destination name
   - Expanded: Full commute details
4. Updates every 30 seconds with latest prediction
5. Ends when trip completes or user cancels

**Technical Details:**
- Uses `ActivityKit` (iOS 16.1+)
- `CommuteActivityManager` manages activities
- Throttled updates (30-second minimum)
- Push token for remote updates (future)

**UI States:**
- Compact: Small icon + leave time
- Minimal: Destination name
- Expanded: Full details (ETA, weather, route)

---

### 5. Personalized Notifications

**Description:**
Daily notifications with personalized messages using user's first name.

**User Flow:**
1. User signs in with Clerk
2. Enables personalized notifications in Settings
3. App schedules 7 daily notifications (one per day)
4. Each notification uses unique message template
5. Messages rotate weekly

**Technical Details:**
- `PersonalizedNotificationScheduler` manages scheduling
- 7 unique message templates (one per day)
- User's firstName from Clerk user object
- Scheduled at 8:00 AM local time
- Cancelled on sign out

**Message Examples:**
- Monday: "Good morning, [FirstName] — This week starts strong..."
- Tuesday: "Hey [FirstName], ready to tackle Tuesday?..."
- Wednesday: "Midweek momentum, [FirstName]!..."

---

### 6. Multi-destination Planner

**Description:**
Users can save and manage multiple regular commutes.

**User Flow:**
1. User creates trip from TripPlannerView
2. Sets destination, arrival time, and repeat days
3. Saves trip
4. Trip appears in TripListView
5. User can toggle trip active/inactive
6. User can edit or delete trips

**Technical Details:**
- `TripStorageService` persists trips locally
- Cloud sync available for authenticated users
- Repeat days: Set of weekdays (Monday-Sunday)
- Active trips trigger notifications

**Trip Properties:**
- Destination (Location)
- Arrival time (Date)
- Buffer minutes (Int)
- Repeat days (Set<WeekDay>)
- Is active (Bool)

---

### 7. Settings

**Description:**
Comprehensive settings for app preferences, subscriptions, and account management.

**Settings Categories:**

#### Notification Settings
- Leave time notifications toggle
- Personalized daily notifications toggle
- Default reminder offsets

#### Appearance
- Theme selection (Light/Dark/System)
- Dynamic Island toggle

#### Account
- Sign in/Sign out
- User profile display

#### Subscription
- Current subscription status
- Upgrade to Premium
- Restore purchases

**Technical Details:**
- `SettingsViewModel` manages state
- `UserPreferencesService` persists preferences
- `SubscriptionService` handles RevenueCat integration

---

### 8. Widgets (Future)

**Description:**
Home Screen widgets showing upcoming trips and leave times.

**Status:** Planned for future release

---

## Premium Features

### Unlimited Trips
- Free tier: 3 active trips
- Premium: Unlimited trips

### Advanced Predictions
- Higher confidence ML models
- Historical pattern analysis
- Alternative route suggestions

### Cloud Sync
- Sync trips across devices
- Backup to cloud
- Multi-device support

### Dynamic Island
- Live Activities in Dynamic Island
- Real-time commute updates
- Lock Screen widgets

---

## Feature Flags

### Clerk Mock Mode
- `COMMUTETIMELY_USE_CLERK_MOCK=true`: Use mock auth for testing

### Prediction Verbose Logging
- `PREDICTION_VERBOSE_LOGGING=true`: Enable detailed prediction logs

### Analytics
- Mixpanel integration (optional)
- Event tracking for user behavior

---

## Feature Dependencies

```
Destination Selection
    └─→ SearchService
        ├─→ AppleMapsSearchService
        └─→ MapboxService

Real-time ETA
    └─→ TrafficWeatherMergeService
        ├─→ MapboxService
        └─→ WeatherService

Leave-time Prediction
    └─→ PredictionEngine
        ├─→ TrafficWeatherMergeService
        ├─→ MLPredictionService
        └─→ UserPreferencesService

Dynamic Island
    └─→ CommuteActivityManager
        └─→ ActivityKit

Personalized Notifications
    └─→ PersonalizedNotificationScheduler
        ├─→ AuthSessionController
        └─→ UserPreferencesService

Multi-destination Planner
    └─→ TripStorageService
        └─→ Local storage / CloudSyncService
```

