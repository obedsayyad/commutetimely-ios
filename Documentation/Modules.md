# Modules

This document describes all major modules in the CommuteTimely app, their responsibilities, and dependencies.

## Core Modules

### App Module (`CommuteTimely/App/`)

**Files:**
- `CommuteTimelyApp.swift`: App entry point, Clerk configuration
- `DIContainer.swift`: Dependency injection container
- `Coordinator.swift`: Navigation coordinator and routes
- `ViewModel.swift`: Base ViewModel protocol and ViewState enum
- `AppConfiguration.swift`: App configuration and environment variables

**Responsibilities:**
- App lifecycle management
- Service dependency injection
- Navigation coordination
- Configuration management

**Dependencies:**
- SwiftUI
- Clerk SDK
- All service protocols

---

### MapView Module (`CommuteTimely/Features/MapView/`)

**Files:**
- `MapView.swift`: Main map interface with MapKit
- `DestinationDetailView.swift`: Destination detail card
- `TrafficOverlayController.swift`: Traffic overlay rendering

**Responsibilities:**
- Interactive map display
- Destination pin management
- Search integration
- Traffic visualization

**Dependencies:**
- MapKit
- LocationService
- SearchService
- TripStorageService

---

### TripPlanner Module (`CommuteTimely/Features/TripPlanner/`)

**Files:**
- `TripPlannerView.swift`: Main trip creation wizard
- `TripListView.swift`: List of saved trips
- `DestinationSearchView.swift`: Destination search interface
- `TripScheduleView.swift`: Arrival time and repeat schedule
- `TripPreviewView.swift`: Trip preview before saving

**Responsibilities:**
- Trip creation and editing
- Destination selection
- Schedule configuration
- Trip list management

**Dependencies:**
- MapboxService
- WeatherService
- MLPredictionService
- TripStorageService
- LeaveTimeScheduler

---

### Authentication Module (`CommuteTimely/Features/Auth/`)

**Files:**
- `AuthLandingView.swift`: Sign-in/sign-up entry point
- `ProfileAuthView.swift`: User profile management
- `AuthPrivacyNoticeView.swift`: Privacy policy display

**Responsibilities:**
- User authentication UI
- Profile management
- Privacy policy display

**Dependencies:**
- Clerk SDK
- AuthSessionController

---

### Settings Module (`CommuteTimely/Features/Settings/`)

**Files:**
- `SettingsView.swift`: Main settings interface
- `PaywallView.swift`: Subscription paywall

**Responsibilities:**
- User preferences management
- Subscription management
- Notification settings
- Theme selection
- Dynamic Island toggle

**Dependencies:**
- UserPreferencesService
- SubscriptionService
- PersonalizedNotificationScheduler
- CommuteActivityManager
- AuthSessionController

---

### Onboarding Module (`CommuteTimely/Features/Onboarding/`)

**Files:**
- `OnboardingCoordinatorView.swift`: Onboarding flow coordinator
- `WelcomeView.swift`: Welcome screen
- `LocationPermissionView.swift`: Location permission request
- `NotificationPermissionView.swift`: Notification permission request

**Responsibilities:**
- First-launch experience
- Permission requests
- Feature introduction

**Dependencies:**
- LocationService
- NotificationService
- AppCoordinator

---

## Service Modules

### Location Service (`CommuteTimely/Services/Location/`)

**File:** `LocationService.swift`

**Responsibilities:**
- GPS location tracking
- Current location updates
- Location authorization management
- Background location updates

**Dependencies:**
- CoreLocation

**Protocol:** `LocationServiceProtocol`

---

### Networking Services (`CommuteTimely/Services/Networking/`)

**Files:**
- `NetworkService.swift`: Base HTTP client with auth
- `MapboxService.swift`: Mapbox Directions API client
- `WeatherbitService.swift`: Weatherbit API client

**Responsibilities:**
- HTTP request handling
- API authentication
- Response parsing
- Error handling

**Dependencies:**
- Alamofire (via NetworkService)
- AuthSessionController (for tokens)

**Protocols:**
- `NetworkServiceProtocol`
- `MapboxServiceProtocol`
- `WeatherServiceProtocol`

---

### Traffic & Weather Module (`CommuteTimely/Services/Traffic/`)

**File:** `TrafficWeatherMergeService.swift`

**Responsibilities:**
- Merging Mapbox traffic data with Weatherbit forecasts
- Caching snapshots (90-second TTL)
- Fallback heuristics when APIs fail
- Weather impact calculation

**Dependencies:**
- MapboxService
- WeatherService

**Protocol:** `TrafficWeatherMergeServiceProtocol`

---

### ML & Prediction Module (`CommuteTimely/Services/ML/`)

**Files:**
- `PredictionEngine.swift`: Orchestrates prediction flow
- `MLPredictionService.swift`: Server ML prediction client

**Responsibilities:**
- Coordinating traffic/weather data with ML predictions
- Fallback to heuristics when ML fails
- Leave time calculation with buffers
- Confidence scoring

**Dependencies:**
- TrafficWeatherMergeService
- MLPredictionService
- UserPreferencesService

**Protocols:**
- `PredictionEngineProtocol`
- `MLPredictionServiceProtocol`

---

### Notifications Module (`CommuteTimely/Services/Notifications/`)

**Files:**
- `NotificationService.swift`: Base notification service
- `LeaveTimeNotificationScheduler.swift`: Leave time notifications
- `LeaveTimeScheduler.swift`: Trip scheduling coordinator
- `PersonalizedNotificationScheduler.swift`: Daily personalized notifications
- `CommuteActivityManager.swift`: Live Activities manager
- `CommuteActivity.swift`: Live Activity attributes
- `CommuteActivityWidget.swift`: Widget extension

**Responsibilities:**
- Local notification scheduling
- Leave time notifications
- Personalized daily notifications
- Live Activities and Dynamic Island
- Background task registration

**Dependencies:**
- UserNotifications
- ActivityKit (iOS 16.1+)
- PredictionEngine
- TripStorageService
- AuthSessionController

**Protocols:**
- `NotificationServiceProtocol`
- `LeaveTimeNotificationSchedulerProtocol`
- `LeaveTimeSchedulerProtocol`
- `PersonalizedNotificationSchedulerProtocol`
- `CommuteActivityManagerProtocol`

---

### Storage Module (`CommuteTimely/Services/Storage/`)

**Files:**
- `TripStorageService.swift`: Trip persistence
- `DestinationStore.swift`: Destination caching
- `UserPreferencesService.swift`: User preferences storage

**Responsibilities:**
- Local trip persistence
- Destination caching
- User preferences storage
- Data synchronization

**Dependencies:**
- UserDefaults
- Core Data (if used)

**Protocols:**
- `TripStorageServiceProtocol`
- `UserPreferencesServiceProtocol`

---

### Search Module (`CommuteTimely/Services/Search/`)

**Files:**
- `SearchService.swift`: Unified search coordinator
- `AppleMapsSearchService.swift`: Apple Maps search client

**Responsibilities:**
- Destination search coordination
- Apple Maps search integration
- Search result caching
- Search debouncing

**Dependencies:**
- MapKit (MKLocalSearch)
- MapboxService
- TripStorageService

**Protocols:**
- `SearchServiceProtocol`
- `AppleMapsSearchServiceProtocol`

---

### Authentication Module (`CommuteTimely/Services/Auth/`)

**File:** `AuthSessionController.swift`

**Responsibilities:**
- Authentication state management
- Clerk integration
- Token management
- User session handling

**Dependencies:**
- Clerk SDK

**Protocol:** `AuthSessionController`

---

### Subscription Module (`CommuteTimely/Services/Subscription/`)

**File:** `SubscriptionService.swift`

**Responsibilities:**
- RevenueCat integration
- Subscription status tracking
- Premium feature gating
- Purchase flow management

**Dependencies:**
- RevenueCat SDK
- AuthSessionController

**Protocol:** `SubscriptionServiceProtocol`

---

### Analytics Module (`CommuteTimely/Services/Analytics/`)

**File:** `AnalyticsService.swift`

**Responsibilities:**
- Event tracking
- User behavior analytics
- Mixpanel integration

**Dependencies:**
- Mixpanel SDK (optional)

**Protocol:** `AnalyticsServiceProtocol`

---

### Sync Module (`CommuteTimely/Services/Sync/`)

**File:** `CloudSyncService.swift`

**Responsibilities:**
- Cloud trip synchronization
- Multi-device support
- Conflict resolution

**Dependencies:**
- NetworkService
- AuthSessionController

**Protocol:** `CloudSyncServiceProtocol`

---

### Theme Module (`CommuteTimely/Services/Theme/`)

**File:** `ThemeManager.swift`

**Responsibilities:**
- Theme management (light/dark)
- Theme persistence
- Theme change notifications

**Dependencies:**
- UserDefaults
- AnalyticsService

---

## Design System Module (`CommuteTimely/DesignSystem/`)

**Files:**
- `Tokens/DesignTokens.swift`: Design tokens (colors, typography, spacing)
- `Components/CTButton.swift`: Reusable button component
- `Components/CTCard.swift`: Card component
- `Components/CTTextField.swift`: Text field component
- `Components/TripListCell.swift`: Trip list cell component

**Responsibilities:**
- Design system tokens
- Reusable UI components
- Consistent styling

**Dependencies:**
- SwiftUI

---

## Models Module (`CommuteTimely/Models/`)

**Files:**
- `Trip.swift`: Trip model
- `Prediction.swift`: Prediction model
- `RouteInfo.swift`: Route information model
- `WeatherData.swift`: Weather data model
- `UserPreferences.swift`: User preferences model

**Responsibilities:**
- Data models
- Codable conformance
- Model validation

---

## Utilities Module (`CommuteTimely/Utilities/`)

**Files:**
- `PremiumFeatureGate.swift`: Premium feature gating modifier

**Responsibilities:**
- Utility functions
- Feature gating
- Helper extensions

---

## Module Dependencies Graph

```
App
├─→ DIContainer (provides all services)
├─→ Coordinator (navigation)
└─→ ViewModels

ViewModels
├─→ Services (via DIContainer)
└─→ Models

Services
├─→ NetworkService (HTTP)
├─→ LocationService (GPS)
├─→ MapboxService → NetworkService
├─→ WeatherService → NetworkService
├─→ TrafficWeatherMergeService → MapboxService + WeatherService
├─→ MLPredictionService → NetworkService
├─→ PredictionEngine → TrafficWeatherMergeService + MLPredictionService
└─→ NotificationService → PredictionEngine

Views
├─→ ViewModels
└─→ DesignSystem
```

