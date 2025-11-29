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
   CLERK_PUBLISHABLE_KEY = pk_test_xxx
   CLERK_FRONTEND_API = https://clerk.your-instance.com
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

