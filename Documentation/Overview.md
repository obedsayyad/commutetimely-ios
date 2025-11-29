# CommuteTimely - Overview

## What is CommuteTimely?

CommuteTimely is an intelligent iOS app that helps users arrive at their destinations on time by predicting optimal leave times based on real-time traffic conditions, weather forecasts, and machine learning predictions.

## Value Proposition

CommuteTimely solves the daily problem of "when should I leave?" by:

- **Real-time Intelligence**: Combines live traffic data from Mapbox with weather forecasts from Weatherbit to provide accurate travel time estimates
- **Machine Learning Predictions**: Uses server-side ML models to predict optimal leave times with confidence scores
- **Personalized Notifications**: Sends timely reminders with personalized messages based on user preferences
- **Dynamic Island Integration**: Provides live commute updates directly in the Dynamic Island on supported devices
- **Multi-destination Planning**: Save and manage multiple regular commutes with repeat schedules

## Why It Exists

Traditional navigation apps tell you how long a trip will take *now*, but they don't help you plan ahead. CommuteTimely bridges this gap by:

1. Analyzing traffic patterns and weather conditions for your target arrival time
2. Calculating when you should leave to account for delays
3. Proactively notifying you when it's time to go
4. Learning from your commute patterns to improve predictions

## Technical Components

### Frontend (iOS)
- **SwiftUI** for modern, declarative UI
- **MapKit** for map display and user interaction
- **MVVM Architecture** with dependency injection via DIContainer
- **Clerk** for authentication
- **Live Activities** and Dynamic Island for real-time updates

### Backend Services
- **Flask REST API** for ML predictions (`/predict` endpoint)
- **Mapbox Directions API** for routing and traffic data
- **Weatherbit API** for current and forecast weather
- **Clerk** for user authentication and session management

### Data Pipeline
```
User Input → MapKit UI → PredictionEngine → Server → Mapbox/Weatherbit → ML Model → Leave Time Recommendation
```

## Premium Features

- **Unlimited Trips**: Free tier limited to 3 active trips
- **Personalized Notifications**: Custom notification messages with user's first name
- **Advanced Predictions**: Higher confidence ML models with historical pattern analysis
- **Cloud Sync**: Sync trips across devices via authenticated backend
- **Dynamic Island**: Live commute updates in Dynamic Island (iOS 16+)

## Architecture Summary

- **Pattern**: MVVM with Coordinator-based navigation
- **Dependency Injection**: Centralized DIContainer for all services
- **State Management**: Combine publishers and @Published properties
- **Networking**: Protocol-based services with async/await
- **Storage**: Local persistence with UserDefaults and Core Data
- **Background Processing**: Background tasks for prediction updates

## Key Technologies

- **Swift 5.9+** with async/await concurrency
- **SwiftUI** for UI framework
- **MapKit** for maps
- **Combine** for reactive programming
- **Clerk iOS SDK** for authentication
- **Alamofire** for HTTP networking
- **RevenueCat** for subscription management

