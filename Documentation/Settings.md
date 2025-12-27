# Settings

This document describes the Settings feature, its structure, and configuration options.

## Settings Overview

The Settings screen allows users to configure app preferences, manage their account, and control subscription features.

## Settings Structure

### SettingsViewModel

Manages all settings state and interactions:

```swift
@MainActor
class SettingsViewModel: BaseViewModel {
    @Published var preferences: UserPreferences
    @Published var subscriptionStatus: SubscriptionStatus
    @Published var showPermissionAlert: Bool
    
    // Services
    let userPreferencesService: UserPreferencesServiceProtocol
    let subscriptionService: SubscriptionServiceProtocol
    let analyticsService: AnalyticsServiceProtocol
    let personalizedNotificationScheduler: PersonalizedNotificationSchedulerProtocol
    let commuteActivityManager: CommuteActivityManagerProtocol
    let authManager: AuthSessionController
}
```

## Settings Sections

### 1. Notifications

#### Leave-Time Notifications

- **Toggle**: Enable/disable leave-time notifications
- **Default Reminder Offsets**: Buffer minutes (e.g., 10, 15, 20)
- **Behavior**: When enabled, notifications fire at predicted leave time minus buffer

#### Personalized Daily Notifications

- **Toggle**: Enable/disable personalized daily notifications
- **Requires**: User authentication (Clerk)
- **Behavior**: Daily notifications at 8:00 AM with personalized messages

### 2. Appearance

#### Theme Selection

- **Options**: Light, Dark, System
- **Storage**: Persisted in UserPreferences
- **Behavior**: Applies theme immediately

#### Dynamic Island

- **Toggle**: Enable/disable Dynamic Island / Live Activities
- **Requires**: iOS 16.1+
- **Behavior**: Shows live commute updates in Dynamic Island

### 3. Account

#### Sign In / Sign Out

- **Sign In**: Opens Supabase authentication
- **Sign Out**: Signs out and cancels personalized notifications
- **User Info**: Displays user name and email (if signed in)

### 4. Subscription

#### Subscription Status

- **Free Tier**: 3 active trips
- **Premium**: Unlimited trips, advanced features
- **Status Display**: Current subscription status
- **Upgrade Button**: Opens paywall

#### Premium Features

- Unlimited trips
- Advanced predictions
- Cloud sync
- Dynamic Island

#### RevenueCat Configuration

RevenueCat is configured in `CommuteTimelyApp.init()` using keys from `AppSecrets.swift`:

```swift
// Configure RevenueCat
Purchases.configure(withAPIKey: AppSecrets.revenueCatPublicAPIKey)
```

##### Setting Up RevenueCat

1. **Create Products in App Store Connect**
   - Create in-app purchase subscriptions (monthly, yearly, etc.)
   - Note down the product IDs

2. **Configure RevenueCat Dashboard**
   - Add your app in RevenueCat
   - Link to App Store Connect
   - Create entitlements (e.g., "premium")
   - Map products to entitlements

3. **Update AppSecrets.swift**
   - Replace `revenueCatPublicAPIKey` with your actual public API key from RevenueCat Dashboard

4. **Product IDs in PaywallView**
   - Update product IDs in `PaywallViewModel` to match your App Store Connect products:
     ```swift
     private let productIds = [
         "com.develentcorp.CommuteTimely.premium.monthly",
         "com.develentcorp.CommuteTimely.premium.yearly"
     ]
     ```

##### Subscription Service Integration

The subscription service is powered by RevenueCat and StoreKit 2:

```swift
lazy var subscriptionService: SubscriptionServiceProtocol = {
    SubscriptionService(authManager: authManager)
}()
```

Features:
- **Purchase**: Handle in-app purchases through RevenueCat
- **Restore**: Restore previous purchases
- **Entitlements**: Check premium access via entitlement checks
- **Status**: Real-time subscription status updates

##### Connecting Auth to Subscriptions

RevenueCat tracks users by connecting to Supabase user IDs:

```swift
// When user signs in
Purchases.shared.logIn(supabaseUserID)

// When user signs out
Purchases.shared.logOut()
```

This ensures subscription status syncs across devices for the same user.

### 5. About

#### App Information

- **Version**: App version number
- **Build**: Build number
- **Copyright**: Copyright notice

#### Links

- **Privacy Policy**: Opens privacy policy
- **Terms of Service**: Opens terms of service
- **Support**: Opens support email

## User Preferences Model

### UserPreferences

```swift
struct UserPreferences: Codable {
    var notificationSettings: NotificationSettings
    var appearanceSettings: AppearanceSettings
    var dynamicIslandEnabled: Bool
    var version: Int
}
```

### NotificationSettings

```swift
struct NotificationSettings: Codable {
    var leaveTimeNotificationsEnabled: Bool
    var personalizedDailyNotificationsEnabled: Bool
    var defaultReminderOffsets: [Int]
    var personalizedNotificationDayIndex: Int
}
```

### AppearanceSettings

```swift
struct AppearanceSettings: Codable {
    var theme: Theme
}

enum Theme: String, Codable {
    case light
    case dark
    case system
}
```

## Settings Persistence

### Storage

Settings are persisted via `UserPreferencesService`:

```swift
func updatePreferences(_ preferences: UserPreferences) async throws {
    let data = try JSONEncoder().encode(preferences)
    UserDefaults.standard.set(data, forKey: "userPreferences")
}
```

### Loading

Settings are loaded on app launch:

```swift
func loadPreferences() async -> UserPreferences {
    guard let data = UserDefaults.standard.data(forKey: "userPreferences"),
          let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
        return UserPreferences() // Default preferences
    }
    return preferences
}
```

## Settings Updates

### Updating Preferences

```swift
func updateLeaveTimeNotifications(enabled: Bool) async {
    var preferences = await userPreferencesService.loadPreferences()
    preferences.notificationSettings.leaveTimeNotificationsEnabled = enabled
    try? await userPreferencesService.updatePreferences(preferences)
    
    if enabled {
        // Schedule notifications for active trips
    } else {
        // Cancel all leave-time notifications
    }
}
```

### Theme Updates

```swift
func updateTheme(_ theme: Theme) async {
    var preferences = await userPreferencesService.loadPreferences()
    preferences.appearanceSettings.theme = theme
    try? await userPreferencesService.updatePreferences(preferences)
    
    // Theme applied immediately via ThemeManager
    themeManager.setTheme(theme)
}
```

## Entitlements

### Required Entitlements

- **Background Modes**: Location updates, Background fetch
- **Push Notifications**: For local notifications
- **Associated Domains**: For Clerk authentication

### Capabilities

Configured in Xcode:
- **Signing & Capabilities** → **+ Capability**
- Add required capabilities

## Dynamic Island Toggle

### Enabling/Disabling

```swift
func updateDynamicIsland(enabled: Bool) async {
    var preferences = await userPreferencesService.loadPreferences()
    preferences.dynamicIslandEnabled = enabled
    try? await userPreferencesService.updatePreferences(preferences)
    
    if !enabled {
        // End all active Live Activities
        await commuteActivityManager.endAllActivities()
    }
}
```

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

## Notification Preferences

### Default Reminder Offsets

User can set default buffer minutes:

```swift
func updateDefaultReminderOffsets(_ offsets: [Int]) async {
    var preferences = await userPreferencesService.loadPreferences()
    preferences.notificationSettings.defaultReminderOffsets = offsets
    try? await userPreferencesService.updatePreferences(preferences)
}
```

### Personalized Notification Day Index

Tracks which day of week for message rotation:

```swift
var personalizedNotificationDayIndex: Int {
    // 0 = Monday, 1 = Tuesday, ..., 6 = Sunday
    Calendar.current.component(.weekday, from: Date()) - 2
}
```

## Subscription Section

### Subscription Status

```swift
struct SubscriptionStatus {
    let isPremium: Bool
    let activeTripsCount: Int
    let maxTripsCount: Int
    let expirationDate: Date?
}
```

### Premium Feature Gating

```swift
func isPremiumFeatureAvailable(_ feature: PremiumFeature) -> Bool {
    return subscriptionStatus.isPremium
}
```

### Paywall

Opens `PaywallView` when user taps "Upgrade":

```swift
.sheet(isPresented: $showingPaywall) {
    PaywallView()
}
```

## Settings UI

### SettingsView Structure

```swift
struct SettingsView: View {
    @StateObject private var viewModel = DIContainer.shared.makeSettingsViewModel()
    
    var body: some View {
        NavigationView {
            List {
                NotificationsSection()
                AppearanceSection()
                AccountSection()
                SubscriptionSection()
                AboutSection()
            }
        }
    }
}
```

### Section Components

- **NotificationsSection**: Notification toggles and preferences
- **AppearanceSection**: Theme and Dynamic Island toggle
- **AccountSection**: Sign in/out, user info
- **SubscriptionSection**: Subscription status and upgrade
- **AboutSection**: App info and links

## Default Values

### Default Preferences

```swift
UserPreferences(
    notificationSettings: NotificationSettings(
        leaveTimeNotificationsEnabled: true,
        personalizedDailyNotificationsEnabled: false,
        defaultReminderOffsets: [10],
        personalizedNotificationDayIndex: 0
    ),
    appearanceSettings: AppearanceSettings(
        theme: .system
    ),
    dynamicIslandEnabled: true,
    version: 1
)
```

## Migration

### Version Migration

When preferences version changes:

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

## Testing Settings

### Unit Tests

```swift
func testThemeUpdate() async {
    let viewModel = SettingsViewModel(...)
    await viewModel.updateTheme(.dark)
    
    let preferences = await userPreferencesService.loadPreferences()
    XCTAssertEqual(preferences.appearanceSettings.theme, .dark)
}
```

### UI Tests

```swift
func testSettingsNavigation() {
    let app = XCUIApplication()
    app.launch()
    
    app.tabBars.buttons["Settings"].tap()
    XCTAssertTrue(app.navigationBars["Settings"].exists)
}
```

