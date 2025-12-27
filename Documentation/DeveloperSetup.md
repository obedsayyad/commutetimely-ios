# Developer Setup

This guide will help you set up the CommuteTimely project for development.

## Prerequisites

### Software Requirements

- **Xcode 15.0+** (iOS 16.0+ target)
- **macOS 13.0+** (Ventura or later)
- **Swift 5.9+**
- **Python 3.8+** (for mock server)
- **Git** (for version control)

### API Keys Required

1. **Mapbox** - Get from https://account.mapbox.com/access-tokens/
   - Already configured: `pk.eyJ1IjoiY29tbXV0ZXRpbWVseSIsImEiOiJjbWUzMzUydmcwMmN1MmtzZnoycGs1ZDhhIn0.438vHnYipmUNS7JoCglyMg`

2. **Weatherbit** - Get from https://www.weatherbit.io/account/dashboard
   - Already configured: `836afe5ccf9c46e1bc2fa3a894f676b3`

3. **Clerk** - Get from https://clerk.com/
   - Create account and get publishable key

4. **RevenueCat** (Optional) - Get from https://app.revenuecat.com/
   - Required for subscription features

5. **Mixpanel** (Optional) - Get from https://mixpanel.com/
   - Required for analytics

## Step 1: Clone Repository

```bash
cd /Users/apple/Desktop/xcode/CommuteTimely
```

Or if cloning from remote:

```bash
git clone <repository-url>
cd CommuteTimely
```

## Step 2: Configure API Keys

### Copy Template

```bash
cp ios/Resources/Secrets.template.xcconfig ios/Resources/Secrets.xcconfig
```

### Edit Secrets.xcconfig

Open `Secrets.xcconfig` and configure your keys:

```properties
MAPBOX_ACCESS_TOKEN = pk.eyJ1IjoiY29tbXV0ZXRpbWVseSIsImEiOiJjbWUzMzUydmcwMmN1MmtzZnoycGs1ZDhhIn0.438vHnYipmUNS7JoCglyMg
WEATHERBIT_API_KEY = 836afe5ccf9c46e1bc2fa3a894f676b3
PREDICTION_SERVER_URL = http://localhost:5000
CLERK_PUBLISHABLE_KEY = pk_test_your_clerk_key_here
REVENUECAT_API_KEY = your_revenuecat_key_here
MIXPANEL_TOKEN = your_mixpanel_token_here
```

**Note:** Mapbox and Weatherbit keys are already configured. You only need to add Clerk, RevenueCat, and Mixpanel keys if using those features.

## Step 3: Add Swift Package Dependencies

### Open Project in Xcode

```bash
open ios/CommuteTimely.xcodeproj
```

### Add Packages

1. Select project in navigator
2. Select "CommuteTimely" target
3. Go to "Package Dependencies" tab
4. Click "+" to add packages

### Required Packages

#### Alamofire
- **URL**: `https://github.com/Alamofire/Alamofire.git`
- **Version**: 5.8.0 or higher

#### Clerk
- **URL**: `https://github.com/clerk/clerk-ios.git`
- **Version**: Latest

### Optional Packages

#### RevenueCat
- **URL**: `https://github.com/RevenueCat/purchases-ios.git`
- **Version**: 4.30.0 or higher

#### Mixpanel
- **URL**: `https://github.com/mixpanel/mixpanel-swift.git`
- **Version**: 4.1.0 or higher

## Step 4: Configure Build Settings

### Set Configuration Files

1. Select project in navigator
2. Go to **Info** tab → **Configurations**
3. Set both Debug and Release to use `Secrets.xcconfig`

### Verify Info.plist

Ensure `Info.plist` is properly configured:
- Location usage descriptions
- Notification permissions
- Background modes

## Step 5: Setup Mock Server

### Create Virtual Environment

```bash
cd server
python3 -m venv venv
source venv/bin/activate
```

### Install Dependencies

```bash
pip install -r requirements.txt
```

### Start Server

```bash
python app.py
```

Server runs on `http://localhost:5000`

### Test Server

```bash
curl http://localhost:5000/health
```

Should return:
```json
{
  "status": "healthy",
  "timestamp": "...",
  "service": "CommuteTimely Prediction API",
  "version": "1.0.0"
}
```

## Step 6: Build & Run

### Clean Build

In Xcode:
1. **Product** → **Clean Build Folder** (⇧⌘K)
2. **Product** → **Build** (⌘B)

### Run in Simulator

1. Select simulator (e.g., iPhone 15 Pro)
2. **Product** → **Run** (⌘R)

### First Launch

On first launch, you'll see:
1. **Welcome Screen** - Onboarding flow
2. **Location Permission** - Request location access
3. **Notification Permission** - Request notification access
4. **Main Screen** - Trip list (empty initially)

## Step 7: Clerk Setup (Optional)

### Create Clerk Application

1. Go to https://clerk.com/
2. Create account
3. Create new application
4. Copy publishable key

### Configure Clerk

1. Add publishable key to `Secrets.xcconfig`
2. Configure Associated Domains in Xcode:
   - Add domain: `webcredentials:your-clerk-frontend-api`
   - Enable in Capabilities

### Mock Mode (Testing)

For testing without Clerk:

1. Edit Scheme → Run → Arguments → Environment Variables
2. Add: `COMMUTETIMELY_USE_CLERK_MOCK` = `true`

## Troubleshooting

### Build Errors

**Package Resolution Failed:**
```bash
# Reset package caches
File → Packages → Reset Package Caches
```

**Missing Secrets.xcconfig:**
- Ensure file exists and is added to project
- Check build configuration uses Secrets.xcconfig

### Runtime Errors

**API Key Errors:**
- Verify keys in `Secrets.xcconfig`
- Check keys are valid and not expired

**Server Connection Failed:**
- Ensure mock server is running
- Check `PREDICTION_SERVER_URL` in Secrets.xcconfig

**Clerk Errors:**
- Verify publishable key is correct
- Check Associated Domains configuration
- Try mock mode for testing

### Common Issues

**"Cannot find module":**
- Clean build folder (⇧⌘K)
- Reset package caches
- Rebuild project

**"Signing errors":**
- Select development team in Signing & Capabilities
- Ensure bundle identifier is unique

## Development Workflow

### Running Tests

```bash
# Unit tests
⌘U

# UI tests
⌘U (select UI test target)
```

### Debugging

**Breakpoints:**
- Set breakpoints in Xcode
- Use LLDB debugger

**Logging:**
- Check console for debug logs
- Enable verbose logging: `PREDICTION_VERBOSE_LOGGING=true`

### Code Style

- Follow Swift style guide
- Use SwiftLint (if configured)
- Format code with Xcode formatter (⌘I)

## Next Steps

1. **Read Architecture.md** - Understand system design
2. **Read Modules.md** - Learn about modules
3. **Read APIs.md** - Understand API contracts
4. **Run Tests** - Verify everything works
5. **Create First Trip** - Test the app

## Additional Resources

- **Swift Documentation**: https://swift.org/documentation/
- **SwiftUI Guides**: https://developer.apple.com/tutorials/swiftui
- **Clerk Docs**: https://clerk.com/docs
- **Mapbox Docs**: https://docs.mapbox.com/
- **Weatherbit Docs**: https://www.weatherbit.io/api

