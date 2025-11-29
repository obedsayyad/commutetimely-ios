# Deployment

This guide covers building and deploying CommuteTimely to the App Store.

## Prerequisites

- Apple Developer account ($99/year)
- App Store Connect access
- Valid provisioning profiles
- App Store Connect app record created

## Build Configuration

### Release Build Settings

1. Select project → **CommuteTimely** target
2. Go to **Build Settings**
3. Set **Configuration** to **Release**
4. Verify:
   - **Code Signing**: Automatic or manual
   - **Bundle Identifier**: `com.commutetimely.app` (or your identifier)
   - **Version**: Current version (e.g., 1.0.0)
   - **Build**: Build number (e.g., 1)

### Archive Settings

1. Select **Any iOS Device** as destination
2. **Product** → **Archive**
3. Wait for archive to complete

## Code Signing

### Automatic Signing

1. Select target → **Signing & Capabilities**
2. Enable **Automatically manage signing**
3. Select your **Team**
4. Xcode will create provisioning profiles automatically

### Manual Signing

1. Disable **Automatically manage signing**
2. Select **Provisioning Profile**
3. Ensure profile matches bundle identifier

### Capabilities

Required capabilities:
- **Background Modes**: Location updates, Background fetch
- **Push Notifications**: For local notifications
- **Associated Domains**: For Clerk authentication

## App Store Connect

### Create App Record

1. Go to https://appstoreconnect.apple.com/
2. **My Apps** → **+** → **New App**
3. Fill in:
   - **Platform**: iOS
   - **Name**: CommuteTimely
   - **Primary Language**: English
   - **Bundle ID**: Your bundle identifier
   - **SKU**: Unique identifier

### App Information

- **Category**: Navigation or Productivity
- **Subtitle**: "Intelligent commute planning"
- **Keywords**: commute, traffic, navigation, ETA
- **Support URL**: Your support URL
- **Marketing URL**: Your marketing URL (optional)

### Privacy Policy

Required for App Store submission:
- **Privacy Policy URL**: Your privacy policy URL
- Must cover:
  - Location data collection
  - User authentication
  - Analytics (if used)

## App Store Assets

### Screenshots

Required sizes:
- **6.7" Display**: 1290 x 2796 pixels (iPhone 14 Pro Max)
- **6.5" Display**: 1242 x 2688 pixels (iPhone 11 Pro Max)
- **5.5" Display**: 1242 x 2208 pixels (iPhone 8 Plus)

### App Icon

- **1024 x 1024 pixels**
- No transparency
- No rounded corners (Apple adds them)

### App Preview (Optional)

- Video previews of app in action
- Up to 30 seconds
- Various device sizes

## Versioning

### Version Number

Format: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes
- **MINOR**: New features
- **PATCH**: Bug fixes

### Build Number

- Increment for each build
- Must be unique per version
- Can be sequential (1, 2, 3...) or date-based (20251129)

### Updating Version

1. Select target → **General**
2. Update **Version** and **Build**
3. Or use Xcode's version bumping

## Uploading to App Store

### Using Xcode

1. **Product** → **Archive**
2. **Window** → **Organizer**
3. Select archive → **Distribute App**
4. Choose **App Store Connect**
5. Follow wizard:
   - Upload
   - Wait for processing
   - Submit for review

### Using Transporter

1. Export archive as `.ipa`
2. Open **Transporter** app
3. Drag `.ipa` file
4. Click **Deliver**

## App Review

### Review Information

- **Contact Information**: Your contact details
- **Demo Account**: Test account credentials (if needed)
- **Notes**: Any special instructions

### Review Guidelines

Ensure compliance with:
- **App Store Review Guidelines**: https://developer.apple.com/app-store/review/guidelines/
- **Human Interface Guidelines**: https://developer.apple.com/design/human-interface-guidelines/

### Common Rejection Reasons

- **Missing Privacy Policy**: Required for apps that collect data
- **Incomplete Functionality**: App must be fully functional
- **Crash on Launch**: App must not crash
- **Missing Permissions**: Location/notification permissions must be explained

## TestFlight

### Internal Testing

1. Upload build to App Store Connect
2. Add internal testers
3. Testers receive email invitation
4. Install via TestFlight app

### External Testing

1. Upload build
2. Create external test group
3. Add testers (up to 10,000)
4. Submit for Beta App Review
5. Testers receive invitation after approval

## Release

### Phased Release

- **Automatic**: Release to 1% of users, then gradually increase
- **Manual**: Release to all users immediately

### Release Options

1. **Release This Version**: Immediate release
2. **Schedule Release**: Release on specific date
3. **Manual Release**: Release after approval

## Post-Release

### Monitoring

- **App Store Connect**: Download metrics, reviews
- **Analytics**: User behavior, crashes
- **Reviews**: Respond to user feedback

### Updates

1. Fix bugs or add features
2. Increment version number
3. Upload new build
4. Submit for review

## Required Permissions

### Location Permission

**Usage Description:**
```
"CommuteTimely needs your location to calculate accurate travel times and provide leave-time predictions."
```

### Notification Permission

**Usage Description:**
```
"CommuteTimely sends notifications to remind you when to leave for your trips."
```

## Background Modes

Required background modes:
- **Location updates**: For significant location changes
- **Background fetch**: For prediction updates

## Privacy Requirements

### Privacy Manifest

iOS 17+ requires privacy manifest:
- Create `PrivacyInfo.xcprivacy` file
- Declare data collection practices
- List required reason APIs

### Data Collection Disclosure

Must disclose:
- Location data (used for routing)
- User authentication (Clerk)
- Analytics (if used)

## Version History

### 1.0.0 (Initial Release)

- Core trip planning
- Real-time traffic and weather
- Leave-time predictions
- Notifications
- Dynamic Island support

## Support

### Support Email

Provide support email in App Store Connect:
- Users can contact for help
- Required for App Store submission

### Support URL

Provide support URL:
- Help documentation
- FAQ
- Contact form

## Checklist

Before submitting:

- [ ] Version and build numbers set
- [ ] Code signing configured
- [ ] All capabilities enabled
- [ ] Privacy policy URL provided
- [ ] Screenshots uploaded
- [ ] App icon provided
- [ ] Description and keywords filled
- [ ] Test account provided (if needed)
- [ ] App tested on device
- [ ] No crashes or critical bugs
- [ ] Permissions explained
- [ ] Background modes justified

