#!/bin/bash
# CommuteTimely Code Formatting Script
# Formats Swift code using SwiftFormat (if installed) or SwiftLint

set -e

echo "🎨 CommuteTimely Code Formatting"
echo "=================================="
echo ""

# Check for SwiftFormat
if command -v swiftformat >/dev/null 2>&1; then
    echo "📝 Using SwiftFormat..."
    swiftformat ios/CommuteTimely --config config/.swiftformat.yml 2>/dev/null || \
    swiftformat ios/CommuteTimely
    echo "✅ Formatting complete"
elif command -v swiftlint >/dev/null 2>&1; then
    echo "📝 Using SwiftLint autocorrect..."
    swiftlint --fix --config config/.swiftlint.yml
    echo "✅ Formatting complete"
else
    echo "⚠️  Neither SwiftFormat nor SwiftLint found"
    echo "   Install SwiftFormat: brew install swiftformat"
    echo "   Or install SwiftLint: brew install swiftlint"
    exit 1
fi

