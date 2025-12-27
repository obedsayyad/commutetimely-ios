# Persistence

CommuteTimely uses local storage for trips, destinations, and user preferences. Cloud sync is available for authenticated users.

## Storage Architecture

### Storage Services

```
TripStorageService (trips)
    ├─→ Local storage (UserDefaults / Core Data)
    └─→ CloudSyncService (cloud backup)

DestinationStore (destinations)
    └─→ In-memory cache with TTL

UserPreferencesService (preferences)
    └─→ UserDefaults
```

## Trip Storage

### TripStorageService

**Protocol:**
```swift
protocol TripStorageServiceProtocol {
    var trips: AnyPublisher<[Trip], Never> { get }
    func fetchTrips() async -> [Trip]
    func saveTrip(_ trip: Trip) async throws
    func updateTrip(_ trip: Trip) async throws
    func deleteTrip(id: UUID) async throws
    func fetchActiveTrips() async -> [Trip]
}
```

### Storage Implementation

**Current:** UserDefaults (JSON encoding)

```swift
func saveTrip(_ trip: Trip) async throws {
    var trips = await fetchTrips()
    if let index = trips.firstIndex(where: { $0.id == trip.id }) {
        trips[index] = trip
    } else {
        trips.append(trip)
    }
    
    let data = try JSONEncoder().encode(trips)
    UserDefaults.standard.set(data, forKey: "savedTrips")
}
```

**Future:** Core Data for better performance and relationships

### Trip Model

```swift
struct Trip: Identifiable, Codable {
    let id: UUID
    let destination: Location
    let arrivalTime: Date
    let bufferMinutes: Int
    let repeatDays: Set<WeekDay>
    var isActive: Bool
    let createdAt: Date
    var updatedAt: Date
}
```

### Storage Key

- **Key**: `"savedTrips"`
- **Format**: JSON array of Trip objects
- **Encoding**: UTF-8

## Destination Storage

### DestinationStore

**Purpose:** Cache search results to reduce API calls

**Storage:** In-memory dictionary with TTL

```swift
class DestinationStore {
    private var cache: [String: [Location]] = [:]
    private var cacheTimestamps: [String: Date] = [:]
    private let cacheTTL: TimeInterval = 300 // 5 minutes
}
```

### Cache Key

```swift
private func cacheKey(query: String, proximity: Coordinate?) -> String {
    if let proximity = proximity {
        return "\(query)_\(proximity.latitude),\(proximity.longitude)"
    }
    return query
}
```

### Cache Invalidation

- **Time-based**: Expires after 5 minutes
- **Manual**: Clear on app background/foreground
- **Memory pressure**: Cleared automatically by system

## User Preferences Storage

### UserPreferencesService

**Protocol:**
```swift
protocol UserPreferencesServiceProtocol {
    func loadPreferences() async -> UserPreferences
    func updatePreferences(_ preferences: UserPreferences) async throws
}
```

### Storage Implementation

**Storage:** UserDefaults (JSON encoding)

```swift
func loadPreferences() async -> UserPreferences {
    guard let data = UserDefaults.standard.data(forKey: "userPreferences"),
          let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
        return UserPreferences() // Default preferences
    }
    return preferences
}
```

### UserPreferences Model

```swift
struct UserPreferences: Codable {
    var notificationSettings: NotificationSettings
    var appearanceSettings: AppearanceSettings
    var dynamicIslandEnabled: Bool
}

struct NotificationSettings: Codable {
    var leaveTimeNotificationsEnabled: Bool
    var personalizedDailyNotificationsEnabled: Bool
    var defaultReminderOffsets: [Int]
    var personalizedNotificationDayIndex: Int
}

struct AppearanceSettings: Codable {
    var theme: Theme
}

enum Theme: String, Codable {
    case light
    case dark
    case system
}
```

### Storage Key

- **Key**: `"userPreferences"`
- **Format**: JSON object
- **Encoding**: UTF-8

## Cloud Sync

### CloudSyncService

**Purpose:** Sync trips to cloud for multi-device support

**Protocol:**
```swift
protocol CloudSyncServiceProtocol {
    func syncTrip(_ trip: Trip) async throws
    func fetchTrips() async throws -> [Trip]
    func deleteTrip(id: UUID) async throws
}
```

### Sync Flow

```
1. User saves trip locally
   ↓
2. TripStorageService.saveTrip()
   ↓
3. If authenticated:
   └─→ CloudSyncService.syncTrip()
       ├─→ Get auth token
       ├─→ HTTP POST → /sync/trips
       └─→ Trip synced to cloud
   ↓
4. Other devices fetch on launch
   └─→ CloudSyncService.fetchTrips()
       └─→ HTTP GET → /sync/trips
```

### Conflict Resolution

**Current:** Last write wins

**Future:** Merge strategies:
- Timestamp-based
- User preference
- Manual resolution

## Data Migration

### Version Management

Preferences include version for migration:

```swift
struct UserPreferences: Codable {
    var version: Int = 1
    // ... other properties
}
```

### Migration Logic

```swift
func migratePreferencesIfNeeded(_ preferences: UserPreferences) -> UserPreferences {
    var migrated = preferences
    
    if migrated.version < 2 {
        // Migration logic for version 2
        migrated.version = 2
    }
    
    return migrated
}
```

## Backup & Restore

### iCloud Backup

- UserDefaults automatically backed up to iCloud
- Trips and preferences included in backup
- Restored on device restore

### Manual Export (Future)

- Export trips as JSON
- Import trips from JSON
- Share trips between devices

## Performance

### Storage Performance

- **UserDefaults**: Fast for small data (< 1MB)
- **Core Data**: Better for large datasets (future)
- **In-Memory Cache**: Instant access

### Optimization

- **Lazy Loading**: Load trips on demand
- **Caching**: Cache destinations and preferences
- **Batch Operations**: Batch save/update operations

## Security

### Data Encryption

- **UserDefaults**: Encrypted at rest by iOS
- **Keychain**: Used for sensitive data (tokens)
- **Cloud Sync**: HTTPS only

### Privacy

- **Local Only**: Trips stored locally by default
- **Opt-In Sync**: Cloud sync requires authentication
- **No Analytics**: Trip data not sent to analytics

## Testing

### Mock Storage

```swift
class MockTripStorageService: TripStorageServiceProtocol {
    var trips: [Trip] = []
    
    func fetchTrips() async -> [Trip] {
        return trips
    }
    
    func saveTrip(_ trip: Trip) async throws {
        trips.append(trip)
    }
}
```

### Test Data

```swift
let testTrip = Trip(
    id: UUID(),
    destination: Location(...),
    arrivalTime: Date().addingTimeInterval(3600),
    bufferMinutes: 10,
    repeatDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
    isActive: true,
    createdAt: Date(),
    updatedAt: Date()
)
```

## Future Enhancements

1. **Core Data Migration**: Move from UserDefaults to Core Data
2. **Offline Support**: Full offline functionality
3. **Sync Improvements**: Better conflict resolution
4. **Export/Import**: Manual backup/restore
5. **Data Analytics**: Usage analytics (privacy-preserving)

