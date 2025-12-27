# QA Checklist

Use this script before every TestFlight or App Store build.

## Smoke / Golden Path

1. **Fresh Install & Onboarding**
   - Install clean build, run through onboarding, grant *Always* location and notification access.
   - Create “Home” + “Work” destinations from the map.
   - Verify contextual search shows Home/Work chips within 300 ms after typing.

2. **Plan & Save Trip**
   - Open Trip Planner → choose a Mapbox suggestion → set arrival time + buffer.
   - Confirm Trip Preview shows ETA + weather snapshot.
   - Save and ensure a leave-time notification is scheduled (check iOS Settings ▸ Notifications ▸ Scheduled Summary).

3. **Map Interaction**
   - Pan/zoom for 30 s. No dropped frames or flickering traffic overlay.
   - Long-press to drop a pin, open the Destination Detail sheet, rename, set tags, and save.

4. **Notification Flow**
   - In simulator: **Debug ▸ Simulate Background Fetch** to force reschedule.
   - Validate “Leave time updated” banner appears when traffic increases (use mock server heavy scenario).

## Edge Cases

| Scenario | Steps | Expected |
| --- | --- | --- |
| **Traffic spike** | Run mock server with heavy congestion profile, tap “Refresh traffic” badge on map. | Traffic badge shows “Severe traffic”, existing trips rescheduled and notification reason mentions congestion. |
| **Offline** | Toggle **Hardware ▸ Network ▸ None**. | Search shows cached recents/favorites + “Offline, using last known routes” banner. |
| **Location denied** | In Settings deny location, relaunch. | Permission banner visible, recenter button shows alert linking to Settings. |
| **Timezone jump** | In simulator set time zone to GMT+9, ensure existing trips fire at correct UTC timestamp. |
| **Background fetch** | With app in background, use `xcrun simctl push` or **Debug ▸ Simulate Background Fetch**. | Scheduler logs `handleSignificantLocationChange` and updates notifications without UI. |

## Regression sweeps

- Run `xcodebuild -scheme "CommuteTimely" -destination 'platform=iOS Simulator,name=iPhone 14' test`.
- Launch Instruments ▸ Time Profiler for the “Map → Destination details → Save” flow; ensure there are no regressions from the baseline captured in `docs/PERFORMANCE.md`.

Document any failures in the release spreadsheet and file GitHub issues tagged `qa-blocker` before submitting to App Review.

