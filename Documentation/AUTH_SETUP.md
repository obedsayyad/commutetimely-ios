# Clerk Authentication Setup

CommuteTimely now uses [Clerk](https://clerk.com/) for all authentication flows (Apple, Google, email magic links, etc.). This document explains how to configure Clerk for the iOS app, how to run in mock mode, and how server endpoints consume Clerk-issued tokens.

---

## 1. Configure Clerk Dashboard

1. Create a Clerk instance and note the **Publishable Key** and **Frontend API URL**.
2. Enable any social providers (Apple, Google, etc.) directly from the Clerk dashboard. The iOS AuthView automatically surfaces the enabled providers.
3. If your backend requires custom JWT templates, create them under **JWT Templates** and reference them from the server.

---

## 2. Xcode Configuration

1. **Secrets.xcconfig**
   ```bash
   CLERK_PUBLISHABLE_KEY = pk_live_Y2xlcmsuY29tbXV0ZXRpbWVseS5jb20k
   CLERK_FRONTEND_API = https://clerk.commutetimely.com
   COMMUTETIMELY_USE_CLERK_MOCK = NO
   ```
   The publishable key is public, but do not commit production values. The frontend API is used for associated domains and passkeys.

2. **Associated Domains**
   - `CommuteTimely/CommuteTimely.entitlements` contains `webcredentials:YOUR_FRONTEND_API_URL`.
   - Replace the value with `webcredentials:{your clerk frontend api}`.
   - Ensure the Associated Domains capability is enabled in Signing & Capabilities.

3. **App bootstrap**
   - `CommuteTimelyApp` reads `CLERK_PUBLISHABLE_KEY` and calls `Clerk.shared.configure(...)` + `Clerk.shared.load()`.
   - Tokens are automatically refreshed and exposed via `ClerkAuthController`.

---

## 2.1 Native iOS App Checklist (CommuteTimely)

This section documents the **concrete values** used by the current CommuteTimely app so you can mirror them exactly in the Clerk Dashboard.

- **Bundle ID**
  - iOS app target uses: `com.develentcorp.CommuteTimely`
  - In Clerk Dashboard → **Native Applications → iOS → Allowed bundle identifiers**, add:
    - `com.develentcorp.CommuteTimely`

- **Clerk Publishable Key**
  - Defined in `ios/Resources/Secrets.xcconfig`:
    ```bash
    CLERK_PUBLISHABLE_KEY = pk_live_Y2xlcmsuY29tbXV0ZXRpbWVseS5jb20k
    ```
  - `AppConfiguration.clerkPublishableKey`:
    - Trims whitespace.
    - Strips trailing `$` (xcconfig delimiter), yielding a valid `pk_test_…` key.
    - Validates prefix is `pk_test_` or `pk_live_`.
  - In Clerk Dashboard, make sure:
    - This publishable key belongs to the same instance that has `https://clerk.commutetimely.com` as its Frontend API.
    - The key is **not truncated** when you paste it into `Secrets.xcconfig`.

- **Frontend API / Associated Domains**
  - `Secrets.xcconfig`:
    ```bash
    CLERK_FRONTEND_API = https://clerk.commutetimely.com
    ```
  - `CommuteTimely/CommuteTimely/CommuteTimely.entitlements`:
    ```xml
    <key>com.apple.developer.associated-domains</key>
    <array>
      <string>webcredentials:clerk.commutetimely.com</string>
    </array>
    ```
  - Requirements:
    - The **domain part** of `CLERK_FRONTEND_API` must match the `webcredentials:` entry exactly (no `https://` prefix).
    - In Xcode → Target `CommuteTimely` → Signing & Capabilities:
      - Add **Associated Domains**.
      - Ensure the entry `webcredentials:clerk.commutetimely.com` is present for all configurations.
    - In Clerk Dashboard, verify the Frontend API is `https://clerk.commutetimely.com`.

- **Clerk Native API & SDK**
  - The project uses the official Swift package:
    - `https://github.com/clerk/clerk-ios`
  - In `CommuteTimely.xcodeproj`:
    - The package reference `XCRemoteSwiftPackageReference "clerk-ios"` is added with product `Clerk`.
    - The `Clerk` product is attached to the **CommuteTimely app target** (not tests).
  - In Clerk Dashboard:
    - Ensure the **Native API** is enabled for the iOS application that uses:
      - Bundle ID `com.develentcorp.CommuteTimely`
      - The above publishable key and frontend API.

- **App entrypoint configuration**
  - `CommuteTimelyApp` does the recommended Native SDK wiring:
    - `import Clerk`
    - `@State private var clerk = Clerk.shared`
    - Root view injects the environment:
      ```swift
      RootView()
        .environmentObject(coordinator)
        .environmentObject(themeManager)
        .environment(\.clerk, clerk)
      ```
    - In `.task` on the root scene, the app:
      - Calls `configureClerkIfNeeded()` in `init` (once at startup).
      - Awaits `loadClerkIfNeeded()` which:
        - Verifies the publishable key format.
        - Logs the bundle ID for cross-checking with Clerk Dashboard.
        - Calls `clerk.load()` with retry and timeout logic.

- **Auth UI usage**
  - **Sign-in / onboarding**:
    - `AuthLandingView` and `OnboardingAuthView` use the shared `AuthSessionController` from `DIContainer`.
    - `AuthLandingView` uses `@Environment(\.clerk)` and presents `AuthView` inside `ClerkAuthFullScreen` only on platforms where `canImport(Clerk)` and `iOS >= 17`.
  - **Profile & account management**:
    - `ProfileAuthView` shows `UserButton()` and user info when `authManager.isAuthenticated` is true.
    - `UserProfileView` reads `clerk.user` via `@Environment(\.clerk)` to show the Clerk user and ID.
  - **Navigation semantics**:
    - `RootView` and `MainTabView` intentionally allow the app to function in a signed-out state.
    - Authentication is optional and primarily unlocks sync/personalization (not basic trip planning).

- **Mock mode (CI / local)**
  - Toggle via env or `Secrets.xcconfig`:
    ```bash
    COMMUTETIMELY_USE_CLERK_MOCK = NO | YES
    ```
  - When mock mode is enabled:
    - `AppConfiguration.useClerkMock` is true.
    - `DIContainer.authManager` uses `ClerkMockProvider` instead of `ClerkAuthController`.
    - `CommuteTimelyApp` **skips** `clerk.configure` and `clerk.load`, so no live Clerk traffic occurs.
    - `AuthLandingView` shows a “Complete mock sign-in” button for fast local and UI-test flows.

Use this checklist whenever you:

- Create or update the **Native iOS app** in Clerk Dashboard.
- Rotate publishable keys or change the Frontend API.
- Clone the repo onto a new machine and need to rewire Secrets/entitlements quickly.

---

## 3. Mock Mode (CI, UI tests, offline dev)

Set `COMMUTETIMELY_USE_CLERK_MOCK=true` (env var or `.xcconfig`) to bypass live Clerk traffic. The DI container will install `ClerkMockProvider`, which:

- Provides deterministic fake users & tokens
- Exposes a "Complete mock sign-in" button inside `AuthLandingView`
- Lets UI tests simulate sign-in/sign-out without network calls

Example for UI tests:
```swift
app.launchEnvironment["COMMUTETIMELY_USE_CLERK_MOCK"] = "true"
```

---

## 4. Backend Expectations

Cloud sync and prediction endpoints now expect **Clerk JWTs**:

1. The iOS app calls `session.getToken()` and attaches `Authorization: Bearer <jwt>` headers.
2. The backend should validate tokens using Clerk's server SDK or the JWKS endpoint.
3. There is no longer any custom Keychain storage—Clerk manages secure token storage.

Update server-side docs to mark auth endpoints as Clerk-backed. Existing endpoints (`/sync/*`, `/predict`) remain the same, but authorization logic should verify Clerk tokens instead of legacy providers.

---

## 5. Manual Testing Checklist

1. **Sign in flow**
   - Launch the app
   - Tap “Sign in to sync”
   - AuthView should present all enabled providers
   - Complete sign-in and verify the Settings tab shows the Clerk user (UserButton + Manage Account)

2. **Profile management**
   - Tap “Manage account” to open `UserProfileView`
   - Link/unlink providers from the Clerk UI if enabled

3. **Sign out**
   - Tap “Sign Out” in Settings
   - Verify the account section reverts to “Not signed in”

4. **Mock mode**
   - Run with `COMMUTETIMELY_USE_CLERK_MOCK=true`
   - Tap “Complete mock sign-in”
   - Verify the UI updates immediately without network access

---

## 6. Troubleshooting

| Issue | Fix |
| --- | --- |
| AuthView stays blank | Ensure `clerk.configure(publishableKey:)` is called and `clerk.load()` resolves (watch Xcode logs). |
| Device-to-web passkeys fail | Confirm Associated Domains entitlements point to the exact `CLERK_FRONTEND_API`. |
| Backend rejects tokens | Make sure you validate against Clerk’s JWKS. Tokens now include the Clerk user ID as `sub`. |
| UI tests hitting real Clerk | Set the env var `COMMUTETIMELY_USE_CLERK_MOCK=true` inside the test target. |

---

## 7. References

- [Clerk iOS Quickstart](https://clerk.com/docs/quickstarts/ios)
- [Clerk Associated Domains Guide](https://clerk.com/docs/reference/jwt/associated-domains)
- [Clerk Backend Token Verification](https://clerk.com/docs/reference/backend-api)

