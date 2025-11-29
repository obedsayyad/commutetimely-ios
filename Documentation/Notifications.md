# Notifications

CommuteTimely uses local notifications to remind users when to leave for their trips. The app supports two types of notifications: leave-time notifications and personalized daily notifications.

## Notification Types

### 1. Leave-Time Notifications

**Purpose:** Remind users when to leave for a specific trip.

**Trigger:** Scheduled based on predicted leave time for each trip.

**Content:**
- Title: "Time to Leave"
- Body: "Leave now to arrive at [Destination] by [Arrival Time]"
- Sound: Default notification sound

### 2. Personalized Daily Notifications

**Purpose:** Daily engagement with personalized messages.

**Trigger:** Scheduled at 8:00 AM local time, one per day.

**Content:**
- Title: "CommuteTimely"
- Body: Personalized message with user's first name
- Sound: Default notification sound
- 7 unique messages (one per day of week)

## Architecture

### Notification Services

```
NotificationService (base)
    ├─→ LeaveTimeNotificationScheduler (leave-time notifications)
    ├─→ LeaveTimeScheduler (trip scheduling coordinator)
    └─→ PersonalizedNotificationScheduler (daily notifications)
```

## Leave-Time Notifications

### Scheduling Flow

```
1. User saves trip
   ↓
2. LeaveTimeScheduler.scheduleTrip()
   ↓
3. PredictionEngine.recommendation() → Get leave time
   ↓
4. LeaveTimeNotificationScheduler.schedule()
   ├─→ Calculate notification time (leave time - buffer)
   ├─→ Create UNNotificationRequest
   └─→ UNUserNotificationCenter.add()
   ↓
5. Notification fires at scheduled time
```

### Notification Content

```swift
let content = UNMutableNotificationContent()
content.title = "Time to Leave"
content.body = "Leave now to arrive at \(destination) by \(arrivalTime)"
content.sound = .default
content.userInfo = [
    "tripId": trip.id.uuidString,
    "type": "leaveTime"
]
```

### Rescheduling

Notifications are rescheduled when:
- Prediction updates (background task)
- Significant location change detected
- User manually refreshes trip

### Code Example

```swift
func schedule(
    for trip: Trip,
    leaveTime: Date,
    bufferMinutes: Int
) async throws {
    let notificationTime = leaveTime.addingTimeInterval(-Double(bufferMinutes * 60))
    
    let content = UNMutableNotificationContent()
    content.title = "Time to Leave"
    content.body = "Leave now to arrive at \(trip.destination.displayName) by \(formatTime(trip.arrivalTime))"
    content.sound = .default
    content.userInfo = [
        "tripId": trip.id.uuidString,
        "type": "leaveTime"
    ]
    
    let trigger = UNCalendarNotificationTrigger(
        dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationTime),
        repeats: false
    )
    
    let request = UNNotificationRequest(
        identifier: "leaveTime_\(trip.id.uuidString)",
        content: content,
        trigger: trigger
    )
    
    try await UNUserNotificationCenter.current().add(request)
}
```

## Personalized Daily Notifications

### Message Templates

7 unique messages, one per day:

```swift
private let messageTemplates: [String] = [
    "Good morning, {firstName} — This week starts strong. Let's plan your commute today.",
    "Hey {firstName}, ready to tackle Tuesday? Check your commute times.",
    "Midweek momentum, {firstName}! Your commute insights are ready.",
    "Thursday vibes, {firstName} — Stay ahead with smart commute planning.",
    "Friday energy, {firstName}! Plan your weekend commute now.",
    "Weekend prep, {firstName} — Your commute schedule awaits.",
    "Sunday reset, {firstName}. Get ready for a smooth week ahead."
]
```

### Scheduling Flow

```
1. User signs in and enables personalized notifications
   ↓
2. PersonalizedNotificationScheduler.scheduleDailyNotifications()
   ↓
3. Gets firstName from AuthSessionController
   ↓
4. Schedules 7 notifications (one per day)
   ├─→ Each uses unique message template
   ├─→ Replaces {firstName} with user's name
   └─→ Scheduled at 8:00 AM local time
   ↓
5. Notifications fire daily
```

### Day Index Rotation

Messages rotate based on current day index:

```swift
let dayIndex = preferences.notificationSettings.personalizedNotificationDayIndex

for i in 0..<7 {
    let messageIndex = (dayIndex + i) % 7
    let message = messageTemplates[messageIndex].replacingOccurrences(of: "{firstName}", with: firstName)
    // Schedule notification for day (dayIndex + i)
}
```

### Code Example

```swift
func scheduleDailyNotifications(firstName: String) async throws {
    await cancelAllPersonalizedNotifications()
    
    let preferences = await userPreferencesService.loadPreferences()
    let dayIndex = preferences.notificationSettings.personalizedNotificationDayIndex
    
    for i in 0..<7 {
        let messageIndex = (dayIndex + i) % 7
        let message = messageTemplates[messageIndex].replacingOccurrences(of: "{firstName}", with: firstName)
        
        let content = UNMutableNotificationContent()
        content.title = "CommuteTimely"
        content.body = message
        content.sound = .default
        content.userInfo = [
            "type": "personalized",
            "dayIndex": messageIndex
        ]
        
        // Calculate date for day (today + i)
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: i, to: Date())!
        let components = calendar.dateComponents([.year, .month, .day], from: targetDate)
        var triggerComponents = DateComponents()
        triggerComponents.year = components.year
        triggerComponents.month = components.month
        triggerComponents.day = components.day
        triggerComponents.hour = 8 // 8:00 AM
        triggerComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "\(notificationIdentifierPrefix)_\(i)",
            content: content,
            trigger: trigger
        )
        
        try await UNUserNotificationCenter.current().add(request)
    }
}
```

## Permissions

### Requesting Permission

```swift
func requestAuthorization() async throws -> Bool {
    let center = UNUserNotificationCenter.current()
    let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
    return granted
}
```

### Checking Permission Status

```swift
func checkAuthorizationStatus() async -> UNAuthorizationStatus {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    return settings.authorizationStatus
}
```

## Background Tasks

### Background Fetch

Registered background tasks for prediction updates:

```swift
func registerBackgroundTasks() {
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.commutetimely.prediction-update",
        using: nil
    ) { task in
        self.handleBackgroundPredictionUpdate(task: task as! BGAppRefreshTask)
    }
}
```

### Significant Location Changes

Location changes trigger prediction updates:

```swift
func handleSignificantLocationChange() async {
    guard let location = await locationService.getCurrentLocation() else { return }
    
    let activeTrips = await tripStorageService.fetchActiveTrips()
    for trip in activeTrips {
        // Update prediction and reschedule notification
    }
}
```

## Rescheduling Rules

### When Notifications Are Rescheduled

1. **Background Task**: Periodic updates (every 15 minutes)
2. **Location Change**: Significant location change detected
3. **App Foreground**: When app comes to foreground
4. **Manual Refresh**: User manually refreshes trip

### Rescheduling Logic

```swift
func rescheduleIfNeeded(for trip: Trip) async {
    let newRecommendation = await predictionEngine.recommendation(
        origin: currentLocation,
        destination: trip.destination.coordinate,
        arrivalTime: trip.arrivalTime
    )
    
    let oldLeaveTime = // Get from existing notification
    let newLeaveTime = newRecommendation.recommendedLeaveTimeUtc
    
    // Only reschedule if leave time changed by more than 2 minutes
    if abs(oldLeaveTime.timeIntervalSince(newLeaveTime)) > 120 {
        await leaveTimeNotificationScheduler.cancel(for: trip.id)
        await leaveTimeNotificationScheduler.schedule(
            for: trip,
            leaveTime: newLeaveTime,
            bufferMinutes: trip.bufferMinutes
        )
    }
}
```

## Cancellation

### Cancelling Leave-Time Notifications

```swift
func cancel(for tripId: UUID) async {
    let identifier = "leaveTime_\(tripId.uuidString)"
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
}
```

### Cancelling All Personalized Notifications

```swift
func cancelAllPersonalizedNotifications() async {
    let identifiers = (0..<7).map { "\(notificationIdentifierPrefix)_\($0)" }
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
}
```

## Error Handling

### Notification Errors

- **Permission Denied**: Show alert in Settings
- **Scheduling Failed**: Log error, continue without notification
- **Rescheduling Failed**: Retry on next update cycle

### Fallback Behavior

If notifications fail:
- App continues to function
- User can manually check leave times in app
- No critical functionality lost

## Settings Integration

### Notification Preferences

Users can control notifications in Settings:

- **Leave-time notifications**: Toggle on/off
- **Personalized daily notifications**: Toggle on/off
- **Default reminder offsets**: Set buffer minutes

### Code Example

```swift
@Published var leaveTimeNotificationsEnabled: Bool {
    didSet {
        if leaveTimeNotificationsEnabled {
            // Schedule notifications for active trips
        } else {
            // Cancel all leave-time notifications
        }
    }
}
```

## Testing

### Testing Notifications

1. **Simulator**: Notifications work in simulator
2. **Device**: Test on physical device for best results
3. **Debug**: Use `UNUserNotificationCenter.current().pendingNotificationRequests()` to inspect scheduled notifications

### Test Scenarios

- Schedule notification for 1 minute in future
- Cancel notification
- Reschedule notification
- Test personalized notifications rotation
- Test permission flow

## Future Enhancements

1. **Rich Notifications**: Add images and actions
2. **Interactive Notifications**: Tap to open trip details
3. **Notification Groups**: Group related notifications
4. **Custom Sounds**: Custom notification sounds
5. **Notification Analytics**: Track notification effectiveness

