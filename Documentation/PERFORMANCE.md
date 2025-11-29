# Performance Optimization Guide

Techniques and best practices for optimizing CommuteTimely's performance.

## Profiling with Instruments

### Latest Snapshot (Nov 2025)

| Hotspot | Before | After | Fix |
| --- | --- | --- | --- |
| `MKMapView` annotation churn | ~12 ms / frame | <2 ms / frame | CADisplayLink-throttled `AppleMapView.Coordinator.flushPendingAnnotationUpdates` + marker reuse |
| Traffic overlay requests | 40+ req/min | 4 req/min | `TrafficOverlayController` tile caching + 30 s throttle |
| Search suggestion rendering | 18 ms per keystroke | <5 ms | `SearchService` batching + `SearchSuggestionRow` lightweight layout |
| Trip save latency | 120 ms | 25 ms | `CoreDataDestinationStore` background context with JSON blobs instead of UserDefaults |
| Prediction pipeline | Frequent main-thread ML calls | Off main, cached snapshots | `TrafficWeatherMergeService` + `PredictionEngine` heuristics fallback |

Keep these baselines in mind when running the sessions below.

### Time Profiler

**What it shows:** CPU usage by function
**When to use:** App feels sluggish, high battery drain

**Steps:**
1. Product → Profile (⌘I)
2. Select "Time Profiler"
3. Record during typical usage
4. Filter by "CommuteTimely" in call tree
5. Look for high % Self time functions

**Common hotspots:**
- Heavy view body computations
- Synchronous network calls on main thread
- Unoptimized list rendering

### Main Thread Checker

**What it shows:** UI updates off main thread
**When to use:** Random crashes, UI glitches

**Enable:** Edit Scheme → Diagnostics → Main Thread Checker

**Common issues:**
- Network completion handlers updating @Published
- Background task modifying @State
- Solution: Wrap in `@MainActor` or `DispatchQueue.main.async`

### Allocations

**What it shows:** Memory usage and leaks
**When to use:** Memory warnings, crashes

**Look for:**
- Steadily growing memory (leaks)
- Sudden spikes (large allocations)
- Abandoned memory (unreferenced objects)

### Network

**What it shows:** Network requests and timing
**When to use:** Slow data loading

**Optimize:**
- Batch similar requests
- Cache responses
- Use HTTP/2 multiplexing
- Implement request throttling

## View Rendering Optimization

### Lazy Stacks

**Use LazyVStack/LazyHStack for long lists:**

```swift
// ❌ Bad - Loads all items immediately
ScrollView {
    VStack {
        ForEach(trips) { trip in
            TripCell(trip: trip)
        }
    }
}

// ✅ Good - Only renders visible items
ScrollView {
    LazyVStack {
        ForEach(trips) { trip in
            TripCell(trip: trip)
        }
    }
}
```

### View Identity

**Provide explicit IDs for dynamic content:**

```swift
ForEach(trips, id: \.id) { trip in
    TripRow(trip: trip)
}
```

### @StateObject vs @ObservedObject

```swift
// ✅ Use @StateObject for view-owned objects
@StateObject private var viewModel = TripListViewModel()

// ✅ Use @ObservedObject for injected objects
@ObservedObject var coordinator: AppCoordinator
```

### Minimize Body Computation

```swift
// ❌ Bad - Complex computation in body
var body: some View {
    let filteredTrips = trips.filter { $0.isActive }
                              .sorted { $0.name < $1.name }
    // ...
}

// ✅ Good - Precompute in ViewModel
class ViewModel: ObservableObject {
    @Published var filteredTrips: [Trip] = []
    
    func updateFilter() {
        filteredTrips = trips.filter { $0.isActive }
                            .sorted { $0.name < $1.name }
    }
}
```

## Debouncing User Input

**Search field example:**

```swift
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    private let debouncer = Debouncer(delay: 0.3)
    
    func search() {
        debouncer.debounce {
            await self.performSearch()
        }
    }
}

// In view:
TextField("Search", text: $viewModel.searchText)
    .onChange(of: viewModel.searchText) { _ in
        viewModel.search()
    }
```

## Map Performance

### Throttle Route Updates

```swift
class MapViewModel: ObservableObject {
    private let routeThrottler = ThrottledOperation(minimumInterval: 2.0)
    
    func updateRoute() {
        routeThrottler.execute {
            await self.fetchRoute()
        }
    }
}
```

### Tile Caching

**Mapbox tile caching is automatic, but configure:**

```swift
// Set cache size (default 50MB)
let cacheSize: UInt = 100 * 1024 * 1024 // 100MB
// Configure in MapboxService initialization
```

### Avoid Continuous Redraw

```swift
// ❌ Bad - Redraws constantly
.onAppear {
    Timer.publish(every: 0.1, on: .main, in: .common)
        .sink { updateMapAnnotations() }
}

// ✅ Good - Only update when needed
.onChange(of: trips) { updateMapAnnotations() }
```

## Networking Optimization

### Async/Await with Timeouts

```swift
func fetchData() async throws -> Data {
    let request = URLRequest(url: url, timeoutInterval: 30)
    let (data, _) = try await URLSession.shared.data(for: request)
    return data
}
```

### Request Batching

```swift
// Combine multiple trip sync requests
func syncMultipleTrips(_ trips: [Trip]) async throws {
    try await cloudSyncService.syncTrips(trips)  // Single request
}
```

### Response Caching

```swift
let config = URLSessionConfiguration.default
config.requestCachePolicy = .returnCacheDataElseLoad
config.urlCache = URLCache(
    memoryCapacity: 10 * 1024 * 1024,    // 10 MB memory
    diskCapacity: 50 * 1024 * 1024        // 50 MB disk
)
```

## Background Tasks

### Limit Refresh Frequency

```swift
// Use significant-change location API instead of continuous
locationManager.startMonitoringSignificantLocationChanges()

// Throttle background refreshes
func scheduleBackgroundRefresh() {
    let earliestDate = Date().addingTimeInterval(15 * 60) // 15 minutes
    BGTaskScheduler.shared.submit(request, earliestBeginDate: earliestDate)
}
```

### Background App Refresh

```swift
// Register selective tasks
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.commutetimely.refresh",
    using: nil
) { task in
    await self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
}
```

## Image Optimization

### Use CachedAsyncImage

```swift
// ✅ Cached image loading
CachedAsyncImage(url: profileURL) { image in
    image.resizable().aspectRatio(contentMode: .fill)
} placeholder: {
    ProgressView()
}
```

### Downsample Large Images

```swift
func downsample(imageAt url: URL, to size: CGSize) -> UIImage? {
    let options = [
        kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
        kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height)
    ] as CFDictionary
    
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
        return nil
    }
    
    return UIImage(cgImage: image)
}
```

### Skeleton Loading

```swift
// Show skeleton while loading
Text("Loading...")
    .redacted(reason: isLoading ? .placeholder : [])
```

## Memory Management

### Avoid Retain Cycles

```swift
// ✅ Use weak self in closures
service.fetch { [weak self] result in
    self?.handle(result)
}

// ✅ Use weak in Combine
cancellable = publisher
    .sink { [weak self] value in
        self?.process(value)
    }
```

### Release Large Objects

```swift
class ViewModel {
    var largeDataSet: [Data]?
    
    func clearCache() {
        largeDataSet = nil
        ImageCache.shared.removeAll()
    }
}
```

## Startup Performance

### Reduce Launch Time

**Optimize:**
1. Defer non-critical initialization
2. Use lazy properties
3. Avoid synchronous disk I/O
4. Background thread for heavy tasks

```swift
init() {
    // ✅ Critical only
    self.coreService = CoreService()
    
    // ✅ Defer heavy initialization
    Task.detached(priority: .utility) {
        await self.loadCache()
        await self.syncData()
    }
}
```

### Preload Critical Data

```swift
@main
struct App: App {
    init() {
        // Preload preferences
        _ = DIContainer.shared.userPreferencesService
        
        // Start auth check
        Task {
            await DIContainer.shared.authManager.refreshTokenIfNeeded()
        }
    }
}
```

## Animation Performance

### Use .animation() Sparingly

```swift
// ❌ Bad - Animates everything
.animation(.default)

// ✅ Good - Specific animations
.animation(.spring, value: isExpanded)
```

### Prefer Transaction

```swift
withAnimation(.spring(response: 0.3)) {
    isExpanded.toggle()
}
```

## Database Performance (Future)

When adding Core Data or SQLite:

### Indexing
```swift
// Add indexes to frequently queried fields
entity.indexes = [NSFetchIndexDescription(name: "userId", elements: [...])]
```

### Batch Operations
```swift
// Batch insert instead of individual
context.perform {
    for trip in trips {
        let entity = Trip(context: context)
        // ...
    }
    try? context.save()
}
```

### Background Contexts
```swift
let backgroundContext = container.newBackgroundContext()
backgroundContext.perform {
    // Heavy operations
}
```

## Monitoring in Production

### Track Key Metrics

1. **App Launch Time**
   - Target: < 2 seconds to first screen

2. **API Response Time**
   - Target: < 500ms for 95th percentile

3. **Memory Usage**
   - Target: < 150MB average

4. **Frame Rate**
   - Target: 60fps during scrolling

### Analytics Events

```swift
analyticsService.trackPerformance("route_calculation", duration: elapsed)
analyticsService.trackPerformance("map_render", duration: elapsed)
```

## Performance Checklist

Before release:

- [ ] Profile with Time Profiler
- [ ] Check for memory leaks
- [ ] Verify Main Thread Checker passes
- [ ] Test on older device (iPhone X or older)
- [ ] Measure cold start time
- [ ] Check network usage
- [ ] Verify battery impact
- [ ] Test with slow network
- [ ] Verify accessibility performance
- [ ] Check Dark Mode rendering

## Common Issues & Solutions

### Issue: List scrolling is janky

**Solution:**
- Use LazyVStack
- Simplify cell views
- Profile with Time Profiler
- Check for synchronous work in cell

### Issue: High memory usage

**Solution:**
- Implement image caching with limits
- Release unused data
- Profile with Allocations
- Check for retain cycles

### Issue: Slow map rendering

**Solution:**
- Throttle route updates
- Reduce annotation count
- Use clustering for many pins
- Profile rendering time

### Issue: Background refresh draining battery

**Solution:**
- Use significant-change location
- Increase refresh interval
- Cancel unnecessary requests
- Profile energy usage

## Additional Resources

- [WWDC: Optimize SwiftUI Performance](https://developer.apple.com/videos/play/wwdc2022/10133/)
- [Swift Concurrency Best Practices](https://developer.apple.com/videos/play/wwdc2021/10254/)
- [Instruments Help](https://help.apple.com/instruments/)

