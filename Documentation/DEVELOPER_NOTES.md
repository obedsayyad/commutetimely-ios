# Developer Notes

This guide provides setup instructions, testing procedures, and troubleshooting tips for CommuteTimely development.

## Quick Start

### 1. Verify Clerk iOS Package

Clerk is consumed as a remote Swift Package (https://github.com/clerk/clerk-ios). If it ever drops from the project:

1. Open `CommuteTimely.xcodeproj` in Xcode
2. **File → Add Packages...**
3. Paste `https://github.com/clerk/clerk-ios`
4. Choose the latest tag (currently `0.71.2`)
5. Add the **Clerk** product to the **CommuteTimely** target

Associated domains are required for passwordless/Safari handoff. See the Clerk Setup section below.

### 2. Resolve Dependencies

```bash
xcodebuild -resolvePackageDependencies -scheme "CommuteTimely"
```

This forces Xcode to fetch Clerk, Firebase, RevenueCat, etc.

### 3. Build the App

**In Xcode:**
- Clean Build Folder: **Product → Clean Build Folder** (⇧⌘K)
- Build: **Product → Build** (⌘B)
- Run: **Product → Run** (⌘R)

**From Terminal:**
```bash
xcodebuild -scheme "CommuteTimely" \
  -destination 'platform=iOS Simulator,name=iPhone 14' \
  build
```

Need the full IDE? Launch it directly:

```bash
xed .
```

---

## Running Tests

### Unit Tests (Xcode)

Run all tests:
```
Product → Test (⌘U)
```

### UI Tests

```bash
xcodebuild -scheme "CommuteTimely" \
  -destination 'platform=iOS Simulator,name=iPhone 14' \
  test
```

---

## API Keys & Configuration

All API keys are configured in **`Secrets.xcconfig`**.

### Current Configuration

✅ **Mapbox Access Token** - Already configured (see project memory)  
✅ **Weatherbit API Key** - Already configured (see project memory)  
⚠️ **RevenueCat API Key** - Using test key (`test_dTYrdOBLnXSzoCGrKGqHwaQQYXk`)  
⚠️ **Mixpanel Token** - Placeholder (`your_mixpanel_token_here`)  
⚠️ **Clerk Publishable Key** - Placeholder (`pk_test_your_key_here`)  
⚠️ **Clerk Frontend API** - Placeholder (`https://clerk.your-frontend-api.com`)

### Before Production

Replace placeholder keys with production credentials:

1. **RevenueCat**: Get your API key from [RevenueCat Dashboard](https://app.revenuecat.com/)
2. **Mixpanel**: Create a project at [Mixpanel](https://mixpanel.com/) and copy the token
3. **Clerk**: From the Clerk dashboard copy the publishable key + Frontend API

Edit `Secrets.xcconfig`:
```bash
# Replace with production values
REVENUECAT_API_KEY = your_production_key_here
MIXPANEL_TOKEN = your_mixpanel_token
CLERK_PUBLISHABLE_KEY = pk_live_...
CLERK_FRONTEND_API = https://clerk.your-production-api.com
COMMUTETIMELY_USE_CLERK_MOCK = NO
```

**Important:** Never commit real production keys. Keep `Secrets.xcconfig` in `.gitignore`.

---

## Clerk Setup

1. **Publishable key + Frontend API**
   - Populate `CLERK_PUBLISHABLE_KEY` and `CLERK_FRONTEND_API` in `Secrets.xcconfig`.
   - The publishable key is required at runtime; never hardcode it in source.

2. **Associated Domains**
   - `CommuteTimely/CommuteTimely.entitlements` contains a placeholder `webcredentials:YOUR_FRONTEND_API_URL`.
   - Replace the value with `webcredentials:{your-clerk-frontend-api}`.
   - Enable the **Associated Domains** capability in Xcode if it is not already.

3. **Mock mode for CI / UI tests**
   - Set the env var `COMMUTETIMELY_USE_CLERK_MOCK=true` to bypass live Clerk traffic (e.g. in UI tests or offline dev).
   - The DI container will provision `ClerkMockProvider`, and UI flows expose a "Complete mock sign-in" button for QA automation.

4. **Manual verification**
   - Run `xcodebuild -scheme "CommuteTimely" -destination 'platform=iOS Simulator,name=iPhone 14' build`
   - Launch the app, tap "Sign in to sync", confirm the Clerk `AuthView` appears, and ensure the `UserButton` shows once signed in.

See `docs/AUTH_SETUP.md` for detailed migration notes.

---

## Mock Traffic / Weather & Prediction Server

The project includes a Flask mock server for auth and ML prediction endpoints.

### Setup

1. **Install & run**
   ```bash
   cd server
   python3 -m venv venv
   source venv/bin/activate  # Windows: venv\Scripts\activate
   pip install -r requirements.txt
   FLASK_APP=app.py flask run
   ```
   The server exposes `/predict`, which synthesizes Mapbox-style traffic metadata plus Weatherbit-style weather readings so you can test leave-time logic without hitting production APIs.

2. **Simulate conditions**
   - Open `server/sample_training_data.csv` to tweak congestion, precipitation, or delay columns.
   - Restart `flask run` after editing to load the new scenario.
   - For quick ad‑hoc tests call:
     ```bash
     curl -X POST http://localhost:5000/predict \
       -H "Content-Type: application/json" \
       -d @server/examples/heavy_rain.json
     ```

3. **Point the app at the mock**
   ```
   AUTH_SERVER_URL = http:/$()/localhost:5000
   PREDICTION_SERVER_URL = http:/$()/localhost:5000
   ```
   This routes TrafficWeather + ML requests through the local Flask server so you can verify scheduler + notification behavior offline.

---

## Asset Management

### Color Assets

All color assets use CT-prefixed names to avoid conflicts:
- `BrandPrimary`, `BrandSecondary`
- `PrimaryLight`, `PrimaryDark`, `SecondaryLight`
- `TextPrimary`, `TextSecondary`, `TextTertiary`
- `Surface`, `SurfaceElevated`, `Background`
- `Success`, `Warning`, `Error`, `Info`
- `Border`, `Divider`

### Regenerate Asset Symbols

If you add/remove/rename assets and Xcode doesn't auto-update:

1. In Xcode: **Editor → Refresh Asset Symbols**
2. Or: **Product → Clean Build Folder**, then rebuild

---

## Common Build Issues

### 1. Clerk fails to load (empty AuthView)

**Solution:**
- Ensure `CLERK_PUBLISHABLE_KEY` is set in `Secrets.xcconfig`
- Confirm Associated Domains include `webcredentials:{your frontend api}`
- Check that `AppConfiguration.useClerkMock` is `false` when using real Clerk
- Inspect Xcode logs for `Clerk failed to load` errors

### 2. Actor Isolation Errors

All actor isolation issues have been fixed in this patch. If you see new ones:
- Ensure you're on Xcode 15.0+ (Swift 6 concurrency)
- Mark UI-driven async functions with `@MainActor`
- Use `await` when crossing actor boundaries

### 3. Deprecated API Warnings (onChange)

All `onChange` calls have been updated to iOS 17+ syntax. If warnings persist:
- Clean build folder
- Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/CommuteTimely-*`
- Rebuild

### 4. RevenueCat Sandbox Issues

When testing subscriptions in DEBUG mode:
- Use a sandbox test account
- Purchases won't charge real money
- Test flows in TestFlight for production-like behavior

---

## CI/CD

A GitHub Actions workflow is provided in `.github/workflows/ci.yml`.

### Local Validation (Pre-Push)

Run these before pushing:

```bash
# 1. Resolve packages
xcodebuild -resolvePackageDependencies -scheme "CommuteTimely"

# 2. Build
xcodebuild -scheme "CommuteTimely" \
  -destination 'platform=iOS Simulator,name=iPhone 14' \
  build

# 3. Run tests
xcodebuild -scheme "CommuteTimely" \
  -destination 'platform=iOS Simulator,name=iPhone 14' \
  test
```

### GitHub Actions

On every push/PR, CI will:
- Resolve dependencies
- Build for iOS Simulator
- Run unit + UI tests (with `COMMUTETIMELY_USE_CLERK_MOCK=true`)

---

## Profiling & Performance Playbook

1. **Time Profiler (map interactions)**
   - Xcode → **Product ▸ Profile** → Time Profiler.
   - Record a session of: launch → pan/zoom map → drop a pin → open destination card.
   - Verify `AppleMapView.Coordinator.flushPendingAnnotationUpdates` stays under 2 ms/frame (display link throttling).

2. **Core Animation / Render Server**
   - Use the "Core Animation" instrument to inspect overdraw.
   - Expect a single green pass after the CADisplayLink throttling changes and MKTileOverlay caching.

3. **Main Thread Checker**
   - Run with `-com.apple.CoreData.ConcurrencyDebug 1` to ensure CoreDataDestinationStore stays off the main actor.

4. **Allocations**
   - Filter for `MKPointAnnotation` to confirm the reuse pool is stable (ballpark: <50 live objects when panning around SF).

5. **Energy Log**
   - Simulate a commute (map open + background notification scheduling). Average CPU <15 %, no sustained location polling thanks to `LeaveTimeScheduler`.

Document top regressions/fixes in `docs/PERFORMANCE.md` after each session.

---

## Background Notification / Scheduler Testing

1. **Grant permissions**
   - Run the Onboarding flow once and allow both *Always* location + notifications.

2. **Schedule a trip**
   - Create a trip in Trip Planner or save from the new Destination Detail sheet.
   - Confirm `xcrun simctl push` shows a pending notification ID (`trip_<uuid>_main`).

3. **Simulate background fetch**
   - In the simulator: **Debug ▸ Simulate Background Fetch**. The `LeaveTimeScheduler` will recompute predictions and call `NotificationService.rescheduleNotification`.

4. **Simulate movement**
   - **Features ▸ Location ▸ Freeway Drive** (or custom GPX). Once the user moves ≥500 m, `handleSignificantLocationChange()` triggers and reschedules active trips.

5. **Real device**
   - Build a Debug adhoc build, enable Background App Refresh, lock the device, and walk/drive ~0.5 km. Expect a “Leave time updated” notification if traffic worsens.

---

## Prediction Logging

Set verbose logging when debugging leave-time math:

```
# Option 1: Scheme Environment Variable
COMMUTETIMELY_PREDICTION_VERBOSE=1

# Option 2: Info.plist override (Debug only)
PREDICTION_VERBOSE_LOGGING = YES
```

When enabled, `PredictionEngine` prints the snapshot inputs (distance, congestion, weather) plus the final leave time & confidence. Remember to disable before shipping builds.

---

## Performance Tips

See `docs/PERFORMANCE.md` for detailed optimization guidelines.

**Quick wins:**
- Use `.task` instead of `.onAppear` for async work
- Leverage `@Published` for reactive updates
- Profile with Instruments (⌘I) to identify bottlenecks

---

## Theme System

See `docs/THEME_SYSTEM.md` for theming architecture.

**Quick usage:**
```swift
@ObservedObject var themeManager = DIContainer.shared.themeManager

// Apply to root view
RootView()
    .applyTheme(themeManager)
```

Users can toggle: System / Light / Dark

---

## Fastlane

Fastlane is configured for builds and screenshots.

```bash
# Install
bundle install

# Build for TestFlight
bundle exec fastlane beta

# Generate screenshots
bundle exec fastlane screenshots
```

See `fastlane/Fastfile` and `docs/APP_STORE_SUBMISSION.md` for release workflows.

---

## Questions or Issues?

1. Check `XCODE_SETUP_FIXES.md` for package/build issues
2. Check `docs/AUTH_SETUP.md` for authentication setup
3. Check `IMPLEMENTATION_SUMMARY.md` for architecture overview
4. Open an issue or contact the team

---

**Happy Coding! 🚀**

