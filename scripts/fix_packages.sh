#!/bin/bash
# CommuteTimely Package Fix Script
# Run this to clean all caches and prepare for Xcode rebuild

set -e  # Exit on error

echo "🚀 CommuteTimely Package Fix Script"
echo "===================================="
echo ""

# Step 1: Close Xcode
echo "📱 Step 1: Closing Xcode..."
killall Xcode 2>/dev/null && echo "   ✅ Xcode closed" || echo "   ℹ️  Xcode not running"
sleep 2

# Step 2: Nuclear clean
echo ""
echo "🧹 Step 2: Nuclear clean of all caches..."
rm -rf ~/Library/Developer/Xcode/DerivedData/CommuteTimely-* && echo "   ✅ Deleted CommuteTimely derived data"
rm -rf ~/Library/Caches/org.swift.swiftpm/ && echo "   ✅ Deleted Swift PM caches"
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex && echo "   ✅ Deleted module cache"
cd "$(dirname "$0")/.." && rm -rf .build/ && echo "   ✅ Deleted local .build directory"

# Step 3: Verify source changes
echo ""
echo "🔍 Step 3: Verifying source code changes..."
if grep -q "oldValue, newValue" "ios/CommuteTimely/Features/TripPlanner/DestinationSearchView.swift"; then
    echo "   ✅ onChange fix applied"
else
    echo "   ⚠️  WARNING: onChange fix might not be applied"
fi

if grep -q "primaryFallback" "ios/CommuteTimely/DesignSystem/Tokens/DesignTokens.swift"; then
    echo "   ✅ primaryFallback method exists"
else
    echo "   ⚠️  WARNING: primaryFallback method not found"
fi

if grep -q "@MainActor" "ios/CommuteTimely/Utilities/PremiumFeatureGate.swift"; then
    echo "   ✅ Actor isolation fixes applied"
else
    echo "   ⚠️  WARNING: Actor isolation fixes might not be applied"
fi

# Step 4: Open Xcode
echo ""
echo "🎉 Cleanup complete!"
echo ""
echo "📋 Next steps (in Xcode):"
echo "=========================="
echo "1. Opening Xcode now..."
xed .
sleep 3

echo ""
echo "2. In Xcode menu bar:"
echo "   → File → Packages → Reset Package Caches"
echo "   → Wait for package resolution to complete"
echo ""
echo "3. Confirm Clerk package resolves:"
echo "   → File → Packages → Reset Package Caches"
echo "   → Wait for Clerk (github.com/clerk/clerk-ios) to finish resolving"
echo ""
echo "4. Clean and build:"
echo "   → Product → Clean Build Folder (⇧⌘K)"
echo "   → Product → Build (⌘B)"
echo ""
echo "✅ Script complete! Follow the steps above in Xcode."

