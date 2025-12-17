# Clerk Support Contact Template

Use this template when contacting Clerk Support about the iOS Native SDK loading issue.

---

## Email Subject
```
iOS Native SDK - clerk.load() completes but isLoaded remains false
```

---

## Email Body

```
Hello Clerk Support Team,

I'm experiencing an issue with the Clerk iOS Native SDK where clerk.load() completes 
without throwing errors, but clerk.isLoaded remains false, preventing authentication 
from working.

INSTANCE DETAILS:
- Frontend API: https://clerk.commutetimely.com
- Instance Domain: clerk.commutetimely.com
- Publishable Key: pk_live_Y2xlcmsuY29tbXV0ZXRpbWVseS5jb20k
- Environment: Production (pk_live_)

iOS APP CONFIGURATION:
- Bundle ID: com.develentcorp.CommuteTimely
- Associated Domain: webcredentials:clerk.commutetimely.com
- Clerk iOS SDK: Latest version (via SPM)

ISSUE DESCRIPTION:
The iOS app correctly calls:
1. Clerk.shared.configure(publishableKey: "pk_live_Y2xlcmsuY29tbXV0ZXRpbWVseS5jb20k")
2. try await clerk.load()

The load() method completes without throwing any errors, but clerk.isLoaded remains 
false afterward. The app has retry logic with exponential backoff (3 attempts), 
and all attempts complete "successfully" but isLoaded never becomes true.

CLERK DASHBOARD VERIFICATION:
✅ Bundle ID 'com.develentcorp.CommuteTimely' is listed in:
   Dashboard → Configure → Native Applications → iOS → Allowed Bundle Identifiers

✅ Native API shows as "enabled" in the dashboard

✅ Frontend API domain matches the associated domain in entitlements

✅ No network connectivity issues - app can reach clerk.commutetimely.com

UNUSUAL OBSERVATION:
The publishable key appears unusually short at 44 characters. Typical Clerk 
publishable keys are 60-120+ characters. When decoded, the base64 portion 
(Y2xlcmsuY29tbXV0ZXRpbWVseS5jb20) translates to just "clerk.commutetimely.com" 
- the domain name itself.

This suggests the key may be a placeholder or the instance may not be fully 
provisioned for iOS Native apps.

QUESTION:
Could you please verify on your backend that:
1. The iOS Native API is properly configured for this instance
2. The publishable key pk_live_Y2xlcmsuY29tbXV0ZXRpbWVseS5jb20k is correctly 
   associated with bundle ID com.develentcorp.CommuteTimely
3. The instance is fully provisioned for iOS Native app authentication
4. Whether a different/longer publishable key should be used

The iOS app code, entitlements, and bundle configuration have all been verified 
as correct. The issue appears to be related to backend configuration.

Thank you for your assistance!

Best regards,
[Your Name]
```

---

## Additional Information to Provide if Requested

### Console Logs
```
[Auth] ✓ Clerk publishable key loaded: pk_live_Y2xl...
[Auth] App Bundle ID: com.develentcorp.CommuteTimely
[Auth] ⚠️ Verify this matches your Clerk Dashboard
[Auth] ⚠️ Clerk publishable key may be truncated. Length: 44
[Auth] Loading Clerk... (attempt 1/3)
[Auth] ✗ Clerk.load() completed but isLoaded = false
[Auth] Publishable Key Length: 44 characters
[Auth] Frontend API: https://clerk.commutetimely.com
```

### Code Configuration
- Using official Clerk iOS SDK: https://github.com/clerk/clerk-ios
- Initialization follows Clerk documentation exactly
- @State private var clerk = Clerk.shared at app root
- .environment(\.clerk, clerk) applied to root view
- Synchronous configure() followed by async load() in .task

### Entitlements File Content
```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>webcredentials:clerk.commutetimely.com</string>
</array>
```

### Network Connectivity
- Network connectivity check to https://clerk.commutetimely.com succeeds
- No App Transport Security (ATS) restrictions blocking Clerk domains
- URLSession requests to Clerk domains complete successfully

---

## Clerk Support Channels

- **Documentation**: https://clerk.com/docs
- **Support Portal**: https://clerk.com/support  
- **Community Discord**: https://clerk.com/discord
- **Email**: support@clerk.com

---

## What to Ask For

1. **Verify backend configuration** for iOS Native API on this instance
2. **Check if publishable key is valid** and properly linked to bundle ID
3. **Confirm instance is production-ready** for iOS Native apps
4. **Provide a longer/different publishable key** if current one is invalid
5. **Review any backend errors** related to this bundle ID trying to authenticate

---

## Expected Resolution

Once Clerk Support identifies and fixes the backend configuration:
1. They may provide a new/corrected publishable key
2. Or enable/activate specific features on the instance
3. Or fix bundle ID associations on their backend

After their fix:
1. Update `ios/Resources/Secrets.xcconfig` with any new key
2. Clean build: `rm -rf ~/Library/Developer/Xcode/DerivedData/CommuteTimely-*`
3. Test and verify logs show: `[Auth] ✓ Clerk loaded successfully` and `Clerk.isLoaded = true`

