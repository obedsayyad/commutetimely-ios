#!/bin/bash
#
# test_clerk_config.sh
# CommuteTimely
#
# Test script to verify Clerk configuration and diagnose issues
#

set -e

echo "🔍 Clerk Configuration Diagnostic Tool"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Navigate to project root
cd "$(dirname "$0")/.."

echo "📂 Project root: $(pwd)"
echo ""

# Check if Secrets.xcconfig exists
if [ ! -f "ios/Resources/Secrets.xcconfig" ]; then
    echo -e "${RED}✗ ios/Resources/Secrets.xcconfig not found${NC}"
    echo "  Please create it from Secrets.template.xcconfig"
    exit 1
fi

echo -e "${GREEN}✓ Secrets.xcconfig found${NC}"
echo ""

# Extract configuration values
echo "📋 Reading Configuration..."
echo ""

CLERK_KEY=$(grep "^CLERK_PUBLISHABLE_KEY" ios/Resources/Secrets.xcconfig | cut -d'=' -f2 | tr -d ' ')
CLERK_API=$(grep "^CLERK_FRONTEND_API" ios/Resources/Secrets.xcconfig | cut -d'=' -f2 | tr -d ' ')
USE_MOCK=$(grep "^COMMUTETIMELY_USE_CLERK_MOCK" ios/Resources/Secrets.xcconfig | cut -d'=' -f2 | tr -d ' ')

# Check Bundle ID from project
BUNDLE_ID=$(grep -A 1 "PRODUCT_BUNDLE_IDENTIFIER" ios/CommuteTimely.xcodeproj/project.pbxproj | grep "com.develentcorp" | head -1 | sed 's/.*= \(.*\);/\1/' | tr -d ' ')

echo "Configuration Values:"
echo "---------------------"
echo "Bundle ID: $BUNDLE_ID"
echo "Clerk Key: ${CLERK_KEY:0:20}..."
echo "Frontend API: $CLERK_API"
echo "Mock Mode: $USE_MOCK"
echo ""

# Validate Bundle ID
echo "🔍 Validating Bundle ID..."
if [[ $BUNDLE_ID == "com.develentcorp.CommuteTimely" ]]; then
    echo -e "${GREEN}✓ Bundle ID is correct: $BUNDLE_ID${NC}"
else
    echo -e "${YELLOW}⚠ Bundle ID: $BUNDLE_ID${NC}"
    echo "  Expected: com.develentcorp.CommuteTimely"
    echo "  Verify this matches your Clerk Dashboard"
fi
echo ""

# Validate Clerk Key
echo "🔍 Validating Clerk Publishable Key..."

# Remove trailing $ if present
CLERK_KEY_CLEAN=$(echo "$CLERK_KEY" | sed 's/\$$//')

# Check key length
KEY_LENGTH=${#CLERK_KEY_CLEAN}
echo "Key length: $KEY_LENGTH characters"

if [[ $CLERK_KEY_CLEAN == pk_live_* ]] || [[ $CLERK_KEY_CLEAN == pk_test_* ]]; then
    echo -e "${GREEN}✓ Key format is valid (starts with pk_live_ or pk_test_)${NC}"
    
    if [ $KEY_LENGTH -lt 50 ]; then
        echo -e "${RED}✗ Key appears to be TRUNCATED or INVALID${NC}"
        echo "  Current length: $KEY_LENGTH characters"
        echo "  Expected length: 60-120+ characters"
        echo ""
        echo "  ${YELLOW}This is likely the cause of your Clerk loading issue!${NC}"
        echo ""
        echo "  Action Required:"
        echo "  1. Check Clerk Dashboard → API Keys for a longer key"
        echo "  2. Look for a different publishable key (60+ characters)"
        echo "  3. Contact Clerk Support if no longer key is available"
        echo ""
        
        # Try to decode the key
        BASE64_PART=$(echo "$CLERK_KEY_CLEAN" | sed 's/pk_[^_]*_//')
        if command -v base64 &> /dev/null; then
            DECODED=$(echo "$BASE64_PART" | base64 -d 2>/dev/null || echo "")
            if [ -n "$DECODED" ]; then
                echo "  Decoded key content: $DECODED"
                if [[ $DECODED == *"clerk.commutetimely.com"* ]] && [ ${#DECODED} -lt 30 ]; then
                    echo -e "  ${RED}⚠ Key decodes to just the domain name - this is NOT a valid Clerk key!${NC}"
                fi
            fi
        fi
    else
        echo -e "${GREEN}✓ Key length appears valid ($KEY_LENGTH characters)${NC}"
    fi
else
    echo -e "${RED}✗ Key format is INVALID${NC}"
    echo "  Expected format: pk_live_... or pk_test_..."
    echo "  Current value: ${CLERK_KEY_CLEAN:0:20}..."
fi
echo ""

# Validate Frontend API
echo "🔍 Validating Frontend API..."
if [[ $CLERK_API == https://clerk.commutetimely.com ]]; then
    echo -e "${GREEN}✓ Frontend API is correct: $CLERK_API${NC}"
else
    echo -e "${YELLOW}⚠ Frontend API: $CLERK_API${NC}"
    echo "  Expected: https://clerk.commutetimely.com"
    echo "  If this is different, update both:"
    echo "  - ios/Resources/Secrets.xcconfig"
    echo "  - ios/CommuteTimely/CommuteTimely/CommuteTimely.entitlements"
fi
echo ""

# Check entitlements
echo "🔍 Checking Entitlements..."
if [ -f "ios/CommuteTimely/CommuteTimely/CommuteTimely.entitlements" ]; then
    ENTITLEMENT_DOMAIN=$(grep "webcredentials:" ios/CommuteTimely/CommuteTimely/CommuteTimely.entitlements | sed 's/.*webcredentials:\([^<]*\)<.*/\1/')
    echo "Associated Domain: webcredentials:$ENTITLEMENT_DOMAIN"
    
    # Extract domain from Frontend API
    API_DOMAIN=$(echo "$CLERK_API" | sed 's|https://||' | sed 's|http://||')
    
    if [[ $ENTITLEMENT_DOMAIN == $API_DOMAIN ]]; then
        echo -e "${GREEN}✓ Associated domain matches Frontend API${NC}"
    else
        echo -e "${RED}✗ Associated domain MISMATCH${NC}"
        echo "  Entitlements: $ENTITLEMENT_DOMAIN"
        echo "  Frontend API: $API_DOMAIN"
        echo "  These must match exactly!"
    fi
else
    echo -e "${RED}✗ Entitlements file not found${NC}"
fi
echo ""

# Check mock mode
echo "🔍 Checking Mock Mode..."
if [[ $USE_MOCK == "YES" ]] || [[ $USE_MOCK == "true" ]] || [[ $USE_MOCK == "1" ]]; then
    echo -e "${YELLOW}⚠ Mock mode is ENABLED${NC}"
    echo "  Clerk will not make real API calls"
    echo "  Set COMMUTETIMELY_USE_CLERK_MOCK=NO to test real Clerk"
else
    echo -e "${GREEN}✓ Mock mode is disabled (using real Clerk)${NC}"
fi
echo ""

# Network connectivity test
echo "🌐 Testing Network Connectivity..."
if command -v curl &> /dev/null; then
    if curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$CLERK_API" | grep -q "^[2-4]"; then
        echo -e "${GREEN}✓ Can reach $CLERK_API${NC}"
    else
        echo -e "${RED}✗ Cannot reach $CLERK_API${NC}"
        echo "  Check your internet connection"
        echo "  Verify the Frontend API URL is correct"
    fi
else
    echo -e "${YELLOW}⚠ curl not available, skipping network test${NC}"
fi
echo ""

# Summary
echo "📊 Summary"
echo "=========="
echo ""

if [ $KEY_LENGTH -lt 50 ]; then
    echo -e "${RED}❌ ISSUE FOUND: Clerk publishable key is too short${NC}"
    echo ""
    echo "Next Steps:"
    echo "1. Review: Documentation/CLERK_DASHBOARD_CHECKLIST.md"
    echo "2. Check Clerk Dashboard → API Keys for a longer key"
    echo "3. If needed, contact Clerk Support (see CLERK_SUPPORT_CONTACT_TEMPLATE.md)"
    echo ""
    exit 1
else
    echo -e "${GREEN}✓ Configuration appears valid${NC}"
    echo ""
    echo "If Clerk still fails to load:"
    echo "1. Clean build: rm -rf ~/Library/Developer/Xcode/DerivedData/CommuteTimely-*"
    echo "2. Run app and check console logs"
    echo "3. Review: Documentation/CLERK_DASHBOARD_CHECKLIST.md"
    echo ""
fi

