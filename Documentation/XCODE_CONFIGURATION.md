# Xcode Project Configuration Guide

## Info.plist Configuration

Modern Xcode projects don't require a physical `Info.plist` file. Instead, configure these settings directly in Xcode:

### Step 1: Configure Build Settings

1. Open `CommuteTimely.xcodeproj` in Xcode
2. Select the **CommuteTimely** target
3. Go to **Build Settings** tab
4. Search for "Info.plist"
5. Under **Packaging**, find **Info.plist File**
6. Leave it as `CommuteTimely/Info.plist` (Xcode will generate it)

### Step 2: Add Custom Keys via Target Info

1. Select the **CommuteTimely** target
2. Go to **Info** tab
3. Click **+** to add each custom property:

#### Required Privacy Keys:

| Key | Type | Value |
|-----|------|-------|
| `Privacy - Location When In Use Usage Description` | String | `CommuteTimely needs your location to calculate accurate travel times and provide timely departure notifications for your saved destinations.` |
| `Privacy - Location Always and When In Use Usage Description` | String | `CommuteTimely monitors traffic conditions in the background to send you timely notifications about when to leave. This ensures you arrive on time even when the app isn't open.` |
| `Privacy - Location Always Usage Description` | String | `CommuteTimely uses your location in the background to monitor traffic and weather conditions, ensuring you receive accurate departure time notifications.` |
| `Privacy - Calendars Usage Description` | String | `CommuteTimely can integrate with your calendar to automatically suggest departure times for upcoming events with locations.` |

#### Background Modes:

1. In the **Info** tab, expand **UIBackgroundModes**
2. Add these items:
   - `fetch`
   - `location`
   - `processing`
   - `remote-notification`

#### Background Task Scheduler:

Add **Permitted background task scheduler identifiers**:
- Key: `BGTaskSchedulerPermittedIdentifiers`
- Type: Array
- Items:
  - `com.commutetimely.refresh`
  - `com.commutetimely.prediction`

### Step 3: Configure Build Settings for xcconfig Keys

To read values from `ios/Resources/Secrets.xcconfig` into your app:

1. Go to **Build Settings** tab
2. Search for each key and add as a **User-Defined Setting**:

#### Add These User-Defined Settings:

Click **+** at the top of Build Settings → **Add User-Defined Setting**:

| Setting Name | Value |
|--------------|-------|
| `MAPBOX_ACCESS_TOKEN` | `$(MAPBOX_ACCESS_TOKEN)` |
| `WEATHERBIT_API_KEY` | `$(WEATHERBIT_API_KEY)` |
| `REVENUECAT_API_KEY` | `$(REVENUECAT_API_KEY)` |
| `MIXPANEL_TOKEN` | `$(MIXPANEL_TOKEN)` |
| `PREDICTION_SERVER_URL` | `$(PREDICTION_SERVER_URL)` |

### Step 4: Link xcconfig to Configuration

1. Select the **Project** (not target) in the navigator
2. Go to **Info** tab
3. Under **Configurations**, expand **Debug** and **Release**
4. For **CommuteTimely** target, select `Secrets` from the dropdown

### Step 5: Access Keys in Swift Code

The `AppConfiguration.swift` file already reads these values:

```swift
static var mapboxAccessToken: String {
    value(for: "MAPBOX_ACCESS_TOKEN")
}

private static func value(for key: String) -> String {
    // Reads from Bundle.main.infoDictionary
    guard let value = Bundle.main.infoDictionary?[key] as? String else {
        return "missing_\(key.lowercased())"
    }
    return value
}
```

### Step 6: Verify Configuration

Build the project (⌘ + B). If successful, the configuration is correct!

## Alternative: Using Info.plist with Build Settings

If you prefer a physical Info.plist file:

1. Create `Info.plist` in `CommuteTimely/` folder
2. Right-click in Xcode → **New File** → **Property List**
3. Name it `Info.plist`
4. Add keys as XML:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>MAPBOX_ACCESS_TOKEN</key>
    <string>$(MAPBOX_ACCESS_TOKEN)</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>CommuteTimely needs your location...</string>
    <!-- Add other keys -->
</dict>
</plist>
```

5. In **Build Settings** → **Info.plist File**, set path: `CommuteTimely/Info.plist`
6. **IMPORTANT**: Make sure it's NOT in **Copy Bundle Resources** build phase

## Troubleshooting Build Errors

### "Multiple commands produce Info.plist"

**Cause**: Info.plist is in multiple build phases

**Solution**:
1. Select target → **Build Phases**
2. Expand **Copy Bundle Resources**
3. Find `Info.plist` and remove it (click ➖)
4. Clean build folder (⌘ + Shift + K)
5. Build again (⌘ + B)

### "Missing Info.plist"

**Cause**: Path in Build Settings is wrong

**Solution**:
1. Build Settings → Search "Info.plist File"
2. Verify path matches actual file location
3. Or leave empty to use Xcode's generated plist

### "Cannot find MAPBOX_ACCESS_TOKEN in bundle"

**Cause**: xcconfig not linked or User-Defined Settings not added

**Solution**:
1. Verify `ios/Resources/Secrets.xcconfig` is selected in Configurations
2. Add User-Defined Settings (see Step 3 above)
3. Clean and rebuild

## Quick Fix Command

If you're still getting the error:

```bash
# Remove the Info.plist from git tracking
cd /Users/apple/Desktop/xcode/CommuteTimely
git rm --cached CommuteTimely/Info.plist

# Clean Xcode build
rm -rf ~/Library/Developer/Xcode/DerivedData/CommuteTimely-*
```

Then rebuild in Xcode.

## Summary

For **modern iOS projects**, the recommended approach is:
- ✅ No physical Info.plist file
- ✅ Configure via Target's Info tab
- ✅ Use User-Defined Settings for xcconfig values
- ✅ Access via `Bundle.main.infoDictionary`

This avoids build conflicts and is the Apple-recommended approach for new projects.

