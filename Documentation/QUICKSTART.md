# CommuteTimely - Quick Start Guide

Get the app running in **5 minutes**! ⚡

## Prerequisites

✅ Xcode 15.0+ installed  
✅ macOS 13.0+ (Ventura)  
✅ Python 3.8+ (for mock server)

## Step 1: Open in Xcode

```bash
cd /Users/apple/Desktop/xcode/CommuteTimely
open ios/CommuteTimely.xcodeproj
```

## Step 2: Configure API Keys

The project already has **working API keys configured**:
- ✅ Mapbox: `pk.eyJ1IjoiY29tbXV0ZXRpbWVseSIsImEiOiJjbWUzMzUydmcwMmN1MmtzZnoycGs1ZDhhIn0.438vHnYipmUNS7JoCglyMg`
- ✅ Weatherbit: `836afe5ccf9c46e1bc2fa3a894f676b3`

These are in `ios/Resources/Secrets.xcconfig` and ready to use!

## Step 3: Add Swift Package Dependencies

In Xcode:
1. Click project → **CommuteTimely** target
2. Go to **Package Dependencies** tab
3. Click **+** and add:

### Required (for basic functionality):
```
Alamofire: https://github.com/Alamofire/Alamofire.git
```

### Optional (for full features):
```
MapboxMaps: https://github.com/mapbox/mapbox-maps-ios.git
RevenueCat: https://github.com/RevenueCat/purchases-ios.git
Firebase: https://github.com/firebase/firebase-ios-sdk.git (FirebaseAnalytics only)
Mixpanel: https://github.com/mixpanel/mixpanel-swift.git
```

**Note:** App will build and run with mock services even without packages!

## Step 4: Start Mock Server

Open a terminal and run:

```bash
cd /Users/apple/Desktop/xcode/CommuteTimely/server

# Create virtual environment (first time only)
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Start server
python app.py
```

Server runs on `http://localhost:5000`

**Test it:**
```bash
curl http://localhost:5000/health
```

## Step 5: Build & Run

In Xcode:
1. Select **iPhone 15** simulator
2. Press **⌘ + R** to build and run

## What You'll See

### First Launch:
1. **Welcome Screen** - Beautiful onboarding
2. **Location Permission** - Request with clear explanation
3. **Notification Permission** - Optional but recommended
4. **Main Screen** - Trip list (empty initially)

### Create Your First Trip:
1. Tap **+** button
2. Search for destination (e.g., "San Francisco")
3. Set arrival time
4. Preview prediction
5. Save trip

### Test Predictions:
The app will:
- Calculate route using Mapbox API
- Fetch weather from Weatherbit
- Call ML prediction server
- Show recommended leave time

## Quick Commands

```bash
# Clean build
make clean

# Run tests
make test

# Run linter
make lint

# Start server
make mock-server
```

## Troubleshooting

### "No such module" errors
**Solution:** Wait for SPM packages to resolve, then clean build (⌘ + Shift + K)

### Server connection failed
**Solution:** Ensure Flask server is running: `make mock-server`

### Location/Notification permissions
**Solution:** 
- Simulator: Debug → Location → Custom Location
- Reset: Device → Erase All Content and Settings

## Test the Complete Flow

1. **Launch app** → Complete onboarding
2. **Create trip**:
   - Destination: "Ferry Building, San Francisco"
   - Arrival: 1 hour from now
3. **View prediction**: Should show leave time ~35-40 min from now
4. **Save trip**: Trip appears in list
5. **Background**: App would send notification at leave time

## What's Included

✅ **Complete iOS App** (SwiftUI, iOS 16+)  
✅ **MVVM + Coordinators** architecture  
✅ **10+ Services** (Location, Maps, Weather, ML, etc.)  
✅ **Design System** (Tokens, Components)  
✅ **Onboarding Flow** with permissions  
✅ **Trip Planner** (Search, Schedule, Preview)  
✅ **Settings** with subscriptions  
✅ **Python Mock Server** (Flask + OpenAPI)  
✅ **CoreML Pipeline** docs  
✅ **Unit & UI Tests**  
✅ **CI/CD** (GitHub Actions, Fastlane)  
✅ **Documentation** (README, guides)

## File Structure

```
CommuteTimely/
├── CommuteTimely/          # Main iOS app
│   ├── App/                # Coordinators, DI
│   ├── Features/           # Onboarding, Planner, Settings
│   ├── Services/           # 10+ business logic services
│   ├── Models/             # Data models
│   └── DesignSystem/       # UI components
├── server/                 # Python Flask API
├── ml/training/            # CoreML training docs
├── docs/                   # Additional documentation
├── fastlane/               # CI/CD automation
└── CommuteTimelyTests/     # Unit & UI tests
```

## Next Steps

### For Development:
- Review `README.md` for full documentation
- Check `docs/APP_STORE_SUBMISSION.md` for deployment
- See `ml/training/README.md` for ML model training

### For Production:
- Add real RevenueCat keys to `ios/Resources/Secrets.xcconfig`
- Train actual ML model with historical data
- Deploy prediction server to cloud
- Submit to App Store (see docs)

## Support

- **Documentation**: See `README.md`
- **API Reference**: See `server/openapi.yaml`
- **ML Training**: See `ml/training/README.md`
- **App Store**: See `docs/APP_STORE_SUBMISSION.md`

---

**🎉 You're all set! The app is ready to run.**

**Questions?** All services have mock implementations, so the app works end-to-end even without real API credentials.

**Tip:** The app logs useful information to the Xcode console. Watch for `[Service]` prefixes to see what's happening.

