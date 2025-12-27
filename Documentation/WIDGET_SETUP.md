# Widget Extension Setup Guide

This guide explains how to complete the widget setup in Xcode after the code files have been created.

## Files Created

The following widget extension files have been created:
- `ios/CommuteTimelyWidget/CommuteTimelyWidgetBundle.swift` - Widget bundle entry point
- `ios/CommuteTimelyWidget/CommuteTimelyWidget.swift` - Main widget configuration
- `ios/CommuteTimelyWidget/TripTimelineProvider.swift` - Timeline provider for fetching trip data
- `ios/CommuteTimelyWidget/CommuteTimelyWidgetEntryView.swift` - Widget views for different sizes

## Xcode Configuration Steps

### 1. Create Widget Extension Target

1. In Xcode, go to **File > New > Target**
2. Select **Widget Extension**
3. Name it `CommuteTimelyWidget`
4. Make sure "Include Configuration Intent" is **unchecked** (we're using static configuration)
5. Click **Finish**

### 2. Move Widget Files to Extension Target

1. In Xcode Project Navigator, locate the `CommuteTimelyWidget` folder
2. Select all widget files:
   - `CommuteTimelyWidgetBundle.swift`
   - `CommuteTimelyWidget.swift`
   - `TripTimelineProvider.swift`
   - `CommuteTimelyWidgetEntryView.swift`
3. In the File Inspector (right panel), under **Target Membership**, check **CommuteTimelyWidget**
4. Uncheck **CommuteTimely** (main app target)

### 3. Configure App Group

1. Select the **CommuteTimely** target (main app)
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** and add: `group.com.commutetimely.shared`
6. Repeat steps 1-5 for the **CommuteTimelyWidget** target

### 4. Update Widget Bundle

1. Open `CommuteTimelyWidgetBundle.swift` in the widget extension
2. Ensure it has the `@main` attribute (already added)
3. Delete the default widget file that Xcode created (if any)

### 5. Add Info.plist Entry (if needed)

The widget extension may need an Info.plist entry. Check if the widget extension has an Info.plist and ensure it includes:
- `NSExtension` dictionary with `NSExtensionPointIdentifier` set to `com.apple.widgetkit-extension`

### 6. Build and Test

1. Select the **CommuteTimelyWidget** scheme
2. Build the project (⌘B)
3. Run on a device or simulator
4. Long press on the home screen
5. Tap the **+** button in the top left
6. Search for "Commute Timely"
7. Select a widget size and add it to the home screen

## App Group Identifier

The App Group identifier used is: `group.com.commutetimely.shared`

**Important:** This must match exactly in:
- Main app target's App Groups capability
- Widget extension target's App Groups capability
- `TripStorageService.swift` (line with `appGroupIdentifier`)
- `TripTimelineProvider.swift` (line with `appGroupIdentifier`)

## Widget Features

### Small Widget (2x2)
- Shows destination name
- Displays leave time countdown or arrival time
- Compact view for quick glance

### Medium Widget (4x2)
- Shows destination name with icon
- Displays leave time and arrival time
- Shows travel time if available
- Countdown timer

### Large Widget (4x4)
- Full trip details
- Destination name
- Leave time with countdown
- Arrival time
- Travel time

## Data Sharing

The widget reads trip data from App Group UserDefaults:
- Key: `sharedTrips`
- Format: JSON array of `WidgetTripData`
- Updated automatically when trips are saved/updated/deleted

## Troubleshooting

### Widget Not Appearing
- Ensure App Groups are configured for both targets
- Check that the widget extension target builds successfully
- Verify the `@main` attribute is on `CommuteTimelyWidgetBundle`

### No Data in Widget
- Check that App Group identifier matches in all locations
- Verify trips are being saved (check main app)
- Check Console for errors related to App Group access

### Build Errors
- Ensure all widget files are in the widget extension target
- Check that WidgetKit framework is imported
- Verify iOS deployment target is 16.0+ for both targets

