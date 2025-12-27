#!/bin/bash
# CommuteTimely Build Automation Script
# Builds the iOS app with proper configuration

set -e

SCHEME="CommuteTimely"
PROJECT="ios/CommuteTimely.xcodeproj"
DESTINATION="platform=iOS Simulator,name=iPhone 15"

echo "🔨 CommuteTimely Build Script"
echo "=============================="
echo ""

# Check if Secrets.xcconfig exists
if [ ! -f "ios/Resources/Secrets.xcconfig" ]; then
    echo "⚠️  Secrets.xcconfig not found. Creating from template..."
    cp ios/Resources/Secrets.template.xcconfig ios/Resources/Secrets.xcconfig
    echo "📝 Please edit ios/Resources/Secrets.xcconfig with your API keys"
fi

# Parse arguments
BUILD_TYPE="${1:-debug}"

case "$BUILD_TYPE" in
    debug|d)
        CONFIGURATION="Debug"
        echo "🔧 Building Debug configuration..."
        ;;
    release|r)
        CONFIGURATION="Release"
        echo "🚀 Building Release configuration..."
        ;;
    test|t)
        CONFIGURATION="Debug"
        echo "🧪 Running tests..."
        xcodebuild test \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -configuration "$CONFIGURATION" \
            -destination "$DESTINATION" \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO
        echo "✅ Tests complete"
        exit 0
        ;;
    *)
        echo "Usage: $0 [debug|release|test]"
        exit 1
        ;;
esac

# Build
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    clean build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO

echo "✅ Build complete"

