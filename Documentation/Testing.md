# Testing

This document describes the testing strategy, test structure, and how to run tests for CommuteTimely.

## Test Structure

### Test Targets

- **CommuteTimelyTests**: Unit tests for services and ViewModels
- **CommuteTimelyUITests**: UI tests for user flows

## Unit Tests

### Test Categories

#### Service Tests

**LocationServiceTests:**
- Location authorization
- Current location fetching
- Location updates

**SearchServiceTests:**
- Search functionality
- Result caching
- Error handling

**PredictionEngineTests:**
- Prediction calculation
- Fallback heuristics
- Error handling

**MLPredictionServiceTests:**
- API request formatting
- Response parsing
- Error handling

**TripStorageServiceTests:**
- Trip persistence
- Trip fetching
- Trip updates/deletion

**PersonalizedNotificationSchedulerTests:**
- Notification scheduling
- Message rotation
- Cancellation

**ThemeManagerTests:**
- Theme switching
- Theme persistence

**DestinationStoreTests:**
- Destination caching
- Cache expiration

### ViewModel Tests

**TripPlannerViewModel:**
- Trip creation flow
- Prediction fetching
- Error states

**TripListViewModel:**
- Trip list display
- Trip toggling
- Trip deletion

**SettingsViewModel:**
- Preferences updates
- Subscription status
- Auth state changes

### Mock Services

All tests use mock services:

```swift
class MockServiceContainer: ServiceContainer {
    var locationService: LocationServiceProtocol = MockLocationService()
    var mapboxService: MapboxServiceProtocol = MockMapboxService()
    var weatherService: WeatherServiceProtocol = MockWeatherService()
    // ... more mocks
}
```

### Example Test

```swift
func testPredictionEngineWithValidData() async {
    let engine = PredictionEngine(
        trafficWeatherService: MockTrafficWeatherMergeService(),
        mlService: MockMLPredictionService(),
        userPreferencesService: MockUserPreferencesService()
    )
    
    let recommendation = await engine.recommendation(
        origin: Coordinate(latitude: 37.7749, longitude: -122.4194),
        destination: Coordinate(latitude: 37.7849, longitude: -122.4094),
        arrivalTime: Date().addingTimeInterval(3600)
    )
    
    XCTAssertNotNil(recommendation)
    XCTAssertGreaterThan(recommendation.confidence, 0.5)
}
```

## UI Tests

### Test Flows

#### AuthFlowTests

- Sign in flow
- Sign out flow
- Auth state changes

#### OnboardingFlowTests

- Welcome screen
- Permission requests
- Onboarding completion

#### TripCreationFlowTests

- Destination search
- Trip creation
- Trip saving

#### ThemeToggleTests

- Theme switching
- Theme persistence

### UI Test Example

```swift
func testTripCreation() {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to trip planner
    app.buttons["Create Trip"].tap()
    
    // Search for destination
    let searchField = app.textFields["Search destination"]
    searchField.tap()
    searchField.typeText("Coffee Shop")
    
    // Select first result
    app.tables.cells.firstMatch.tap()
    
    // Set arrival time
    app.datePickers.firstMatch.tap()
    
    // Save trip
    app.buttons["Save"].tap()
    
    // Verify trip appears in list
    XCTAssertTrue(app.tables.cells.containing(.staticText, identifier: "Coffee Shop").exists)
}
```

## Running Tests

### In Xcode

1. **Run All Tests**: ⌘U
2. **Run Current Test**: Click test diamond
3. **Run Test Class**: Right-click class → Run

### Command Line

```bash
# Run all tests
xcodebuild test -scheme CommuteTimely -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test
xcodebuild test -scheme CommuteTimely -only-testing:CommuteTimelyTests/PredictionEngineTests
```

## Test Data

### Mock Data

```swift
let mockTrip = Trip(
    id: UUID(),
    destination: Location(
        coordinate: Coordinate(latitude: 37.7849, longitude: -122.4094),
        address: "123 Main St, San Francisco, CA",
        displayName: "Coffee Shop"
    ),
    arrivalTime: Date().addingTimeInterval(3600),
    bufferMinutes: 10,
    repeatDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
    isActive: true,
    createdAt: Date(),
    updatedAt: Date()
)
```

### Test Fixtures

Create test fixtures for:
- Sample trips
- Sample routes
- Sample weather data
- Sample predictions

## Test Coverage

### Coverage Goals

- **Services**: 80%+ coverage
- **ViewModels**: 70%+ coverage
- **Utilities**: 90%+ coverage

### Viewing Coverage

1. **Product** → **Test** (⌘U)
2. **Report Navigator** → Select test run
3. **Coverage** tab

## Continuous Integration

### GitHub Actions

CI workflow runs on:
- Every push
- Every pull request

### CI Steps

1. Resolve package dependencies
2. Build project
3. Run unit tests
4. Run UI tests (with mock auth)

### CI Configuration

See `.github/workflows/build.yml`

## Mock Server Testing

### Local Mock Server

For testing with real API responses:

```bash
cd server
python app.py
```

### Test Endpoints

```bash
# Health check
curl http://localhost:5000/health

# Prediction
curl -X POST http://localhost:5000/predict \
  -H "Content-Type: application/json" \
  -d @test_prediction_request.json
```

## Deterministic Tests

### Time-Based Tests

Use fixed dates for deterministic tests:

```swift
let fixedDate = Date(timeIntervalSince1970: 1701234567)
let trip = Trip(..., arrivalTime: fixedDate)
```

### Async Testing

Use `XCTestExpectation` for async operations:

```swift
func testAsyncOperation() async {
    let expectation = XCTestExpectation(description: "Async operation")
    
    Task {
        let result = await someAsyncOperation()
        XCTAssertNotNil(result)
        expectation.fulfill()
    }
    
    await fulfillment(of: [expectation], timeout: 5.0)
}
```

## Performance Tests

### Performance Baselines

```swift
func testPredictionPerformance() {
    measure {
        // Prediction calculation
        let recommendation = await predictionEngine.recommendation(...)
    }
}
```

### Performance Metrics

- Prediction calculation: < 2 seconds
- Trip save: < 100ms
- Search: < 500ms

## Snapshot Tests (Future)

### UI Snapshot Testing

Use snapshot testing for UI consistency:
- Screenshot comparisons
- Visual regression testing

## Test Environment

### Environment Variables

Set in test scheme:
- `COMMUTETIMELY_USE_CLERK_MOCK=true`: Use mock auth
- `PREDICTION_VERBOSE_LOGGING=true`: Enable verbose logs

### Test Configuration

Tests use separate configuration:
- Mock services
- Test data
- No external API calls

## Best Practices

### Test Organization

- Group related tests in classes
- Use descriptive test names
- One assertion per test (when possible)

### Test Data

- Use factories for test data
- Keep test data minimal
- Use realistic data

### Mocking

- Mock external dependencies
- Use protocol-based mocks
- Verify mock interactions

## Troubleshooting

### Tests Not Running

- Check test target membership
- Verify test methods start with `test`
- Check test scheme configuration

### Flaky Tests

- Fix timing issues
- Use expectations for async
- Avoid random data

### Slow Tests

- Optimize test data
- Use mocks instead of real services
- Parallelize test execution

