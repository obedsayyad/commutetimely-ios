# Authentication

CommuteTimely uses Supabase for user authentication, providing secure sign-in, user management, and session handling. RevenueCat is used for subscription management and premium feature access.

## Overview

The authentication system consists of two main components:

### Supabase Authentication
- User sign-up and sign-in (email/password, magic link)
- OAuth providers (Apple, Google)
- Session management and token refresh
- User profile management
- Row Level Security (RLS) for data access

### RevenueCat Subscriptions
- Subscription purchase and restoration
- Entitlement management
- Premium feature gating
- Cross-platform subscription sync

## Configuration

### Supabase Setup

1. Create a Supabase project at https://app.supabase.com
2. Get your project URL and anon key from Project Settings → API
3. Update `ios/CommuteTimely/Config/AppSecrets.swift`:
   - Replace `supabaseURL` with your project URL (e.g., `https://your-project-id.supabase.co`)
   - Replace `supabaseAnonKey` with your anon/public key

### RevenueCat Setup

1. Create a RevenueCat project at https://app.revenuecat.com
2. Get your public API key from Projects → [Your App] → API Keys
3. Update `ios/CommuteTimely/Config/AppSecrets.swift`:
   - Replace `revenueCatPublicAPIKey` with your public SDK key

### AppSecrets.swift

All authentication and subscription keys are centralized in `ios/CommuteTimely/Config/AppSecrets.swift`:

```swift
struct AppSecrets {
    // MARK: - Supabase Configuration
    static let supabaseURL = "https://dvvmlhfyabbfcvrohjip.supabase.co"
    static let supabaseAnonKey = "eyJhbGci..."
    
    // MARK: - RevenueCat Configuration
    static let revenueCatPublicAPIKey = "test_dTYrdOBLnXSzoCGrKGqHwaQQYXk"
}
```

### Security Best Practices

- The `AppSecrets.swift` file contains placeholder keys safe for development
- Replace placeholder keys before release builds
- Never commit production keys to version control
- Consider using environment variables or CI/CD secrets for production builds
- The Supabase anon key is designed to be public and protected by Row Level Security (RLS)
- The RevenueCat public key is safe to embed in the app binary

### Configuration in App Entry

Both SDKs are initialized in `CommuteTimelyApp.init()`:

```swift
// Initialize Supabase client
let supabaseClient = SupabaseClient(
    supabaseURL: URL(string: AppSecrets.supabaseURL)!,
    supabaseKey: AppSecrets.supabaseAnonKey
)

// Configure Supabase in DIContainer
serviceContainer.configureSupabase(client: supabaseClient)

// Configure RevenueCat
Purchases.configure(withAPIKey: AppSecrets.revenueCatPublicAPIKey)
```

## Auth Session Controller

### AuthSessionController Protocol

```swift
protocol AuthSessionController {
    var authStatePublisher: AnyPublisher<AuthSessionState, Never> { get }
    func signIn() async throws
    func signOut() async throws
    func idToken() async throws -> String?
    var currentUser: User? { get }
}
```

### Auth States

```swift
enum AuthSessionState {
    case signedOut
    case signedIn(user: User)
    case loading
}
```

## User Model

### User Structure

```swift
struct User {
    let id: String
    let firstName: String?
    let lastName: String?
    let emailAddresses: [EmailAddress]
    let imageUrl: String?
}
```

### User Data Access

```swift
let user = authManager.currentUser
let firstName = user?.firstName ?? "Friend"
```

## Authentication Flow

### Sign In Flow

```
1. User taps "Sign In" in AuthLandingView
   ↓
2. Clerk sign-in UI presented
   ├─→ Email/password
   ├─→ Apple Sign In
   └─→ Google Sign In (future)
   ↓
3. Clerk authenticates user
   ↓
4. authManager.authStatePublisher emits .signedIn(user)
   ↓
5. RootView handles auth state change
   ├─→ PersonalizedNotificationScheduler.scheduleDailyNotifications(firstName: user.firstName)
   └─→ Navigation updates to MainTabView
```

### Sign Out Flow

```
1. User taps "Sign Out" in SettingsView
   ↓
2. authManager.signOut()
   ↓
3. Clerk signs out user
   ↓
4. authManager.authStatePublisher emits .signedOut
   ↓
5. RootView handles auth state change
   ├─→ PersonalizedNotificationScheduler.cancelAllPersonalizedNotifications()
   ├─→ UserPreferencesService disables personalized notifications
   └─→ Navigation updates to OnboardingCoordinatorView
```

## Token Management

### ID Token

ID tokens are used for authenticated backend requests:

```swift
let token = try await authManager.idToken()
```

### Token Usage

Tokens are automatically included in network requests:

```swift
lazy var networkService: NetworkServiceProtocol = {
    NetworkService(authTokenProvider: { [weak self] in
        guard let self else { return nil }
        return try? await self.authManager.idToken()
    })
}()
```

### Token Refresh

Clerk SDK automatically refreshes tokens when they expire. No manual refresh logic needed.

## Auth State Observation

### Observing Auth State

```swift
.task {
    for await state in authManager.authStatePublisher.values {
        await handleAuthStateChange(state)
    }
}
```

### Handling State Changes

```swift
private func handleAuthStateChange(_ state: AuthSessionState) async {
    switch state {
    case .signedOut:
        await personalizedNotificationScheduler.cancelAllPersonalizedNotifications()
        // Update preferences
    case .signedIn(let user):
        if preferences.notificationSettings.personalizedDailyNotificationsEnabled {
            let firstName = user.firstName ?? "Friend"
            try? await personalizedNotificationScheduler.scheduleDailyNotifications(firstName: firstName)
        }
    }
}
```

## Mock Authentication

### Mock Mode

For testing without Clerk:

```swift
if AppConfiguration.useClerkMock {
    return ClerkMockProvider()
}
```

### Mock Provider

`ClerkMockProvider` provides:
- Mock user with test data
- Mock auth state publisher
- Mock token generation
- No actual Clerk API calls

### Enabling Mock Mode

Set environment variable:
```bash
export COMMUTETIMELY_USE_CLERK_MOCK=true
```

Or in Xcode scheme:
- Edit Scheme → Run → Arguments → Environment Variables
- Add: `COMMUTETIMELY_USE_CLERK_MOCK` = `true`

## Integration Points

### DIContainer

```swift
lazy var authManager: AuthSessionController = {
    if AppConfiguration.useClerkMock {
        return ClerkMockProvider()
    }
    #if canImport(Clerk)
    return ClerkAuthController()
    #else
    return ClerkMockProvider()
    #endif
}()
```

### Network Service

Network service uses auth tokens for authenticated requests:

```swift
lazy var networkService: NetworkServiceProtocol = {
    NetworkService(authTokenProvider: { [weak self] in
        guard let self else { return nil }
        return try? await self.authManager.idToken()
    })
}()
```

### Cloud Sync

Cloud sync requires authentication:

```swift
lazy var cloudSyncService: CloudSyncServiceProtocol = {
    CloudSyncService(
        baseURL: AppConfiguration.authServerURL,
        networkService: networkService,
        authTokenProvider: { [weak self] in
            guard let self = self else { return nil }
            return try? await self.authManager.idToken()
        }
    )
}()
```

## UI Components

### AuthLandingView

Main authentication entry point:
- Sign in button
- Sign up button
- Privacy notice link

### ProfileAuthView

User profile management:
- Display user info
- Sign out button
- Account settings (future)

### AuthPrivacyNoticeView

Privacy policy display:
- Terms of service
- Privacy policy
- Data usage information

## Permissions & Privacy

### Required Permissions

- **None**: Clerk handles all authentication internally

### Privacy Notes

- User data stored by Clerk (not locally)
- Tokens stored securely in Keychain
- No personal data sent to CommuteTimely backend (except sync)

### Data Collection

- **Email**: Collected by Clerk for authentication
- **Name**: Optional, used for personalized notifications
- **Profile Image**: Optional, from Clerk

## Error Handling

### Auth Errors

```swift
enum AuthError: Error {
    case signInFailed(Error)
    case signOutFailed(Error)
    case tokenRefreshFailed(Error)
    case userNotFound
}
```

### Error Recovery

- **Sign In Failed**: Show error message, allow retry
- **Token Refresh Failed**: Sign out user, require re-authentication
- **Network Error**: Show offline message, allow retry

## Testing

### Unit Tests

Mock auth provider used in tests:

```swift
let mockAuth = ClerkMockProvider()
let viewModel = SettingsViewModel(
    authManager: mockAuth,
    // ... other dependencies
)
```

### UI Tests

Mock mode enabled in UI tests:

```swift
// In test setup
AppConfiguration.useClerkMock = true
```

## Future Enhancements

1. **Multi-Provider Auth**: Google Sign In, Apple Sign In
2. **Social Login**: Facebook, Twitter
3. **Two-Factor Auth**: SMS, authenticator apps
4. **Account Linking**: Link multiple providers
5. **Profile Management**: Edit profile, change password

