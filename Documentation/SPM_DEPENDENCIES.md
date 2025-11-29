# Swift Package Manager Dependencies

This document lists all required SPM dependencies for CommuteTimely. Add these through Xcode's package manager.

## How to Add Dependencies

1. Open `ios/CommuteTimely.xcodeproj` in Xcode
2. Select the project in the navigator
3. Select the "CommuteTimely" target
4. Go to "Package Dependencies" tab
5. Click "+" to add each package below

## Required Packages

### MapboxMaps
**Repository:** `https://github.com/mapbox/mapbox-maps-ios.git`
**Version:** 10.18.0 or higher
**Usage:** Interactive maps, routing, traffic data

### RevenueCat
**Repository:** `https://github.com/RevenueCat/purchases-ios.git`
**Version:** 4.30.0 or higher
**Usage:** In-app purchase and subscription management

### Alamofire
**Repository:** `https://github.com/Alamofire/Alamofire.git`
**Version:** 5.8.0 or higher
**Usage:** Networking layer for API requests

### Firebase Analytics
**Repository:** `https://github.com/firebase/firebase-ios-sdk.git`
**Version:** 10.18.0 or higher
**Products to Add:** 
- FirebaseAnalytics
- FirebaseCore
**Usage:** Analytics tracking with Firebase adapter

### Mixpanel
**Repository:** `https://github.com/mixpanel/mixpanel-swift.git`
**Version:** 4.1.0 or higher
**Usage:** Analytics tracking with Mixpanel adapter

## Post-Installation Steps

1. **Firebase Setup** (if using Firebase Analytics):
   - Download `GoogleService-Info.plist` from Firebase Console
   - Add it to the CommuteTimely target
   - The file is in .gitignore, so it won't be committed

2. **Build Settings**:
   - Ensure `Info.plist` is set as the Info.plist file
   - Verify `Secrets.xcconfig` is included in build configuration:
     - Select Project → Info → Configurations
     - Set "Debug" configuration to use `Secrets.xcconfig`
     - Set "Release" configuration to use `Secrets.xcconfig`

3. **Mapbox Token**:
   - The token from `Secrets.xcconfig` is automatically read via Info.plist
   - Mapbox SDK will use `MGLMapboxAccessToken` key from Info.plist

## Verification

Run the app in simulator. If configured correctly, you should see no API key warnings in the console.

## Troubleshooting

- **"Missing configuration value"**: Check that `Secrets.xcconfig` exists and has valid values
- **Firebase crash**: Ensure `GoogleService-Info.plist` is added to the target
- **Mapbox not loading**: Verify `MGLMapboxAccessToken` is set in Info.plist

