# Architecture

## System Overview

CommuteTimely follows a **MVVM (Model-View-ViewModel)** architecture pattern with **Dependency Injection** for service management. The app is built with SwiftUI and uses a coordinator-based navigation system.

## Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│  (SwiftUI Views, ViewModels, Coordinators)               │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│                    Service Layer                         │
│  (Protocol-based services, DIContainer)                 │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│                    Data Layer                            │
│  (Networking, Storage, Models)                           │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│                    External APIs                         │
│  (Mapbox, Weatherbit, Clerk, Backend Server)             │
└─────────────────────────────────────────────────────────┘
```

## MVVM Pattern

### Models
- **Trip**: Represents a saved commute with destination, arrival time, and repeat schedule
- **Prediction**: ML prediction result with leave time and confidence
- **RouteInfo**: Mapbox routing data with traffic and geometry
- **WeatherData**: Weatherbit forecast data
- **UserPreferences**: User settings and notification preferences

### Views
- SwiftUI views organized by feature:
  - `TripListView`: List of saved trips
  - `TripPlannerView`: Wizard for creating/editing trips
  - `MapView`: Interactive map with destination pins
  - `SettingsView`: App settings and subscription management
  - `OnboardingCoordinatorView`: First-launch flow

### ViewModels
- All ViewModels inherit from `BaseViewModel`
- Use `@Published` properties for reactive updates
- Handle business logic and service coordination
- Examples:
  - `TripPlannerViewModel`: Manages trip creation flow
  - `TripListViewModel`: Manages trip list state
  - `MapViewModel`: Handles map interactions and search
  - `SettingsViewModel`: Manages settings and preferences

## Dependency Injection

### DIContainer

The `DIContainer` is a singleton that provides all services to the app:

```swift
class DIContainer: ServiceContainer {
    static let shared = DIContainer()
    
    lazy var locationService: LocationServiceProtocol = { ... }()
    lazy var mapboxService: MapboxServiceProtocol = { ... }()
    lazy var weatherService: WeatherServiceProtocol = { ... }()
    lazy var predictionEngine: PredictionEngineProtocol = { ... }()
    // ... more services
}
```

### Service Protocols

All services are protocol-based for testability:

- `LocationServiceProtocol`: GPS location tracking
- `MapboxServiceProtocol`: Routing and traffic data
- `WeatherServiceProtocol`: Weather forecasts
- `MLPredictionServiceProtocol`: Server ML predictions
- `PredictionEngineProtocol`: Orchestrates prediction flow
- `NotificationServiceProtocol`: Local notifications
- `TripStorageServiceProtocol`: Local trip persistence
- `AuthSessionController`: Authentication state

## Data Flow

### Prediction Flow

```
User selects destination
    ↓
TripPlannerViewModel.fetchPrediction()
    ↓
PredictionEngine.recommendation()
    ↓
TrafficWeatherMergeService.snapshot()
    ├─→ MapboxService.getRoute() → Mapbox API
    └─→ WeatherbitService.getCurrentWeather() → Weatherbit API
    ↓
MLPredictionService.predict() → Backend Server /predict
    ↓
LeaveTimeRecommendation returned to ViewModel
    ↓
UI updates with leave time
```

### Authentication Flow

```
App Launch
    ↓
CommuteTimelyApp.configureClerkIfNeeded()
    ↓
Clerk.shared.configure() → Clerk SDK
    ↓
RootView observes authManager.authStatePublisher
    ↓
Auth state changes → Navigation updates
    ├─→ Signed In: MainTabView
    └─→ Signed Out: OnboardingCoordinatorView
```

### Notification Flow

```
Trip saved with arrival time
    ↓
LeaveTimeScheduler.scheduleTrip()
    ↓
PredictionEngine.recommendation() → Get leave time
    ↓
LeaveTimeNotificationScheduler.schedule() → UNUserNotificationCenter
    ↓
Notification fires at leave time
    ↓
User receives notification
```

## Navigation System

### Coordinator Pattern

The app uses `AppCoordinator` for navigation management:

```swift
enum AppRoute {
    case onboarding
    case main
    case tripPlanner(mode: TripPlannerMode)
    case tripDetail(trip: Trip)
    case settings
    case subscription
}
```

### Navigation Flow

```
RootView
    ├─→ OnboardingCoordinatorView (first launch)
    │   ├─→ WelcomeView
    │   ├─→ LocationPermissionView
    │   └─→ NotificationPermissionView
    │
    └─→ MainTabView (after onboarding)
        ├─→ TripListView (Tab 1)
        ├─→ MapView (Tab 2)
        └─→ SettingsView (Tab 3)
```

## Background Services

### Background Tasks

- **Prediction Updates**: Registered via `BGTaskScheduler` to refresh predictions periodically
- **Location Monitoring**: Significant location changes trigger prediction recalculation
- **Notification Scheduling**: Background task to reschedule notifications when predictions change

### Live Activities

- **CommuteActivityManager**: Manages Live Activities and Dynamic Island updates
- Updates every 30 seconds with throttling
- Shows leave time, destination, and ETA
- Automatically ends when trip is complete

## App Lifecycle

### Initialization

1. `CommuteTimelyApp.init()`:
   - Creates `DIContainer.shared`
   - Initializes `AppCoordinator`
   - Configures Clerk authentication
   - Sets up `ThemeManager`

2. `RootView.body`:
   - Observes auth state
   - Routes to onboarding or main view
   - Handles auth state changes

3. `MainTabView`:
   - Creates ViewModels via DIContainer factories
   - Sets up tab navigation
   - Loads initial data

### Background Execution

- App registers background tasks on launch
- Significant location changes trigger updates
- Notifications scheduled via UNUserNotificationCenter
- Live Activities update via ActivityKit

## Error Handling

### Service Errors

All services throw typed errors:
- `MapboxError`: Routing failures
- `WeatherbitError`: Weather API failures
- `NetworkError`: HTTP request failures
- `PredictionError`: ML prediction failures

### Error Recovery

- ViewModels catch errors and update `ViewState.error`
- UI displays error messages to users
- Fallback to heuristic predictions when ML fails
- Cached data used when network unavailable

## Testing Architecture

### Mock Services

`MockServiceContainer` provides test doubles:
- `MockLocationService`
- `MockMapboxService`
- `MockWeatherService`
- `MockMLPredictionService`
- All mocks conform to service protocols

### Test Targets

- **CommuteTimelyTests**: Unit tests for services and ViewModels
- **CommuteTimelyUITests**: UI tests for user flows

