# CommuteTimely

> Never miss your arrival time with AI-powered leave-time predictions

[![CI](https://github.com/your-username/CommuteTimely/actions/workflows/ci.yml/badge.svg)](https://github.com/your-username/CommuteTimely/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)

CommuteTimely is a production-ready iOS app that tells users **exactly when to leave** for their destination by analyzing real-time traffic, weather conditions, and historical patterns using ML predictions.

## ✨ Features

- **🤖 Smart Predictions** - AI analyzes traffic and weather in real-time to calculate optimal leave times
- **🔔 Timely Notifications** - Get alerted when you need to leave with personalized messages
- **🗺️ Route Alternatives** - See backup routes if conditions change
- **☁️ Weather Integration** - Adjusts for rain, snow, and poor visibility
- **📊 Analytics Dashboard** - Track your commute patterns and arrival accuracy
- **💎 Premium Subscriptions** - Unlimited trips with RevenueCat integration
- **🌙 Dynamic Island** - Live commute updates directly in the Dynamic Island (iOS 16+)
- **🔐 Secure Authentication** - Sign in with Apple, Google, or email via Clerk

## 🏗️ Architecture

### Design Pattern

- **MVVM + Coordinators** for clean separation and navigation
- **Dependency Injection** via DIContainer
- **Combine** for reactive data flow
- **Swift Package Manager** for dependencies

### Project Structure

```
CommuteTimely/
├── ios/                          # iOS application
│   ├── CommuteTimely/           # Main iOS app
│   │   ├── App/                 # App entry, coordinators, DI
│   │   ├── Features/            # Feature modules (MVVM)
│   │   │   ├── Onboarding/     # Welcome & permissions
│   │   │   ├── TripPlanner/   # Trip creation flow
│   │   │   ├── MapView/        # Map integration
│   │   │   ├── Auth/           # Authentication UI
│   │   │   └── Settings/      # Settings & subscription
│   │   ├── Services/           # Business logic
│   │   │   ├── Location/      # Location services
│   │   │   ├── Networking/    # API clients
│   │   │   ├── Analytics/     # Firebase & Mixpanel
│   │   │   ├── ML/            # Prediction service
│   │   │   └── Notifications/ # Notification scheduling
│   │   ├── Models/            # Data models & DTOs
│   │   ├── DesignSystem/      # UI tokens & components
│   │   └── Resources/        # Assets & strings
│   ├── CommuteTimelyTests/    # Unit tests
│   ├── CommuteTimelyUITests/  # UI tests
│   └── Resources/             # iOS config files
│       ├── Secrets.xcconfig
│       └── Secrets.template.xcconfig
│
├── server/                     # Python Flask backend
│   ├── app.py                 # Main Flask application
│   ├── auth_service.py        # Authentication service
│   ├── requirements.txt       # Python dependencies
│   ├── Dockerfile             # Container configuration
│   └── README.md              # Server documentation
│
├── ml/                        # Machine Learning
│   ├── training/              # Training scripts
│   │   ├── sample_training_data.csv
│   │   └── README.md
│   ├── notebooks/            # Jupyter notebooks
│   └── datasets/             # Training datasets
│
├── Documentation/            # Project documentation
│   ├── Overview.md
│   ├── Architecture.md
│   ├── API.md
│   └── ...
│
├── scripts/                  # Build & utility scripts
│   ├── fix_packages.sh
│   ├── format.sh
│   └── build.sh
│
├── config/                   # Configuration files
│   └── .swiftlint.yml
│
└── fastlane/                # CI/CD automation
```

## 📋 Prerequisites

### Software Requirements

- **Xcode 15.0+** (iOS 16.0+ target)
- **macOS 13.0+** (Ventura)
- **Swift 5.9+**
- **Python 3.8+** (for mock server)

### API Keys Required

1. **Mapbox** - Get from https://account.mapbox.com/access-tokens/
2. **Weatherbit** - Get from https://www.weatherbit.io/account/dashboard
3. **Clerk** - Get from https://clerk.com/ (for authentication)
4. **RevenueCat** (Optional) - Get from https://app.revenuecat.com/
5. **Mixpanel** (Optional) - Get from https://mixpanel.com/

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/CommuteTimely.git
cd CommuteTimely
```

### 2. Configure API Keys

Copy the template and add your keys:

```bash
cp ios/Resources/Secrets.template.xcconfig ios/Resources/Secrets.xcconfig
```

Edit `ios/Resources/Secrets.xcconfig` and replace placeholders:

```properties
MAPBOX_ACCESS_TOKEN = your_actual_mapbox_token_here
WEATHERBIT_API_KEY = your_actual_weatherbit_key_here
CLERK_PUBLISHABLE_KEY = your_clerk_publishable_key_here
REVENUECAT_API_KEY = your_revenuecat_key_here
MIXPANEL_TOKEN = your_mixpanel_token_here
PREDICTION_SERVER_URL = http://localhost:5000
```

### 3. Install Dependencies

```bash
# Install Swift Package dependencies
make install

# Or manually
xcodebuild -resolvePackageDependencies -project ios/CommuteTimely.xcodeproj
```

### 4. Start the Prediction Server

```bash
# Using Makefile
make mock-server

# Or manually
cd server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py
```

The server will run on `http://localhost:5000`

### 5. Build & Run

```bash
# Using Makefile
make dev

# Or open in Xcode
open ios/CommuteTimely.xcodeproj
# Then: ⌘ + R to run
```

## 📱 Installation

### For Users

CommuteTimely is available on the App Store (coming soon).

### For Developers

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed setup instructions.

## 🧪 Testing

### Run All Tests

```bash
make test
```

### Run Specific Test Suites

```bash
# Unit tests only
xcodebuild test \
  -project ios/CommuteTimely.xcodeproj \
  -scheme CommuteTimely \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:CommuteTimelyTests

# UI tests only
xcodebuild test \
  -project ios/CommuteTimely.xcodeproj \
  -scheme CommuteTimely \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:CommuteTimelyUITests
```

### Code Quality

```bash
# Run SwiftLint
make lint

# Format code
./scripts/format.sh
```

## 🔧 Development

### Makefile Commands

```bash
make install      # Install dependencies and resolve SPM packages
make test         # Run unit and UI tests
make lint         # Run SwiftLint
make clean        # Clean build artifacts
make mock-server  # Start Python Flask prediction server
make dev          # Build for development (simulator)
make build-release # Build release configuration
```

### Adding a New Feature

1. Create feature folder in `ios/CommuteTimely/Features/`
2. Implement View + ViewModel (MVVM)
3. Add navigation route in `Coordinator`
4. Register dependencies in `DIContainer`
5. Write unit tests
6. Add UI tests for critical paths
7. Update documentation

## 🤖 Machine Learning

### Training Your Own Model

See `ml/training/README.md` for:
- Feature engineering pipeline
- Training with LightGBM/XGBoost
- CoreML conversion
- Model evaluation metrics

### Model Architecture

The app uses a hybrid prediction approach:
1. **Primary**: Server-based ML predictions (Python Flask)
2. **Fallback**: On-device CoreML model for offline/low-latency

## 📚 Documentation

Comprehensive documentation is available in the `Documentation/` directory:

- [Overview](Documentation/Overview.md) - Project overview and value proposition
- [Architecture](Documentation/Architecture.md) - System architecture and design patterns
- [API Documentation](Documentation/API.md) - API endpoints and usage
- [Prediction Engine](Documentation/PredictionEngine.md) - ML prediction system
- [Design System](Documentation/DesignSystem.md) - UI components and tokens
- [Testing Guide](Documentation/Testing.md) - Testing strategies and best practices
- [Developer Setup](Documentation/DeveloperSetup.md) - Detailed setup instructions

## 🚢 Deployment

### App Store Submission

See `Documentation/APP_STORE_SUBMISSION.md` for:
- Required assets and metadata
- Review notes template
- Testing instructions
- Privacy policy requirements

### Server Deployment

See `server/README.md` and `Documentation/BACKEND_DEPLOYMENT.md` for:
- Docker deployment
- Environment configuration
- Production considerations

## 🔒 Privacy & Security

### Data Collection

- **Location**: Used only for route calculation and traffic monitoring
- **Analytics**: Opt-in only, can be disabled in Settings
- **No PII**: User IDs are hashed before server transmission

### Security Measures

- API keys in `ios/Resources/Secrets.xcconfig` (gitignored)
- User tokens stored in Keychain
- HTTPS for all network requests
- Receipt validation via RevenueCat

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Mapbox** for mapping and routing services
- **Weatherbit** for weather data
- **Clerk** for authentication
- **RevenueCat** for subscription management
- **Apple** for CoreML and native frameworks

## 📞 Support

- **GitHub Issues**: [Create an issue](https://github.com/your-username/CommuteTimely-ios/issues)
- **Email**: hellot@commutetimely.com
- **Documentation**: See `Documentation/` folder

## 🗺️ Roadmap

- [ ] Widget support for home screen
- [ ] Apple Watch app
- [ ] CarPlay integration
- [ ] Multi-language support
- [ ] Advanced analytics dashboard
- [ ] Social features (share trips with friends)

---

**Built with ❤️ using SwiftUI**

Version: 1.0.0  
Last Updated: November 2024
