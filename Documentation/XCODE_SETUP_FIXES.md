# Xcode Setup Fixes

This guide addresses the remaining compilation errors.

## Issue 1: Clerk package missing / build errors

> The old `CommuteTimelyAuth` package was deleted. If you still see instructions about adding `Packages/CommuteTimelyAuth`, replace them with the Clerk steps below.

The local SPM package needs to be added to the Xcode project.

### Solution A: Add via Xcode UI (Recommended)

1. **Open Xcode** with `CommuteTimely.xcodeproj`
2. Select **CommuteTimely project** (blue icon at top)
3. Go to **Project Settings** (not Target settings)
4. Select **CommuteTimely** under "PROJECT" (not TARGETS)
5. Go to **"Package Dependencies"** tab
6. Click **"+"** button at bottom
7. Click **"Add Local..."** 
8. Navigate to: `/Users/apple/Desktop/xcode/CommuteTimely/Packages/CommuteTimelyAuth`
9. Click **"Add Package"**
10. When prompted, select **"CommuteTimelyAuth"** library
11. Choose **"Add to Target: CommuteTimely"**
12. Click **"Add Package"**

### Solution B: Add via File Menu

1. **File → Add Package Dependencies...**
2. Click **"Add Local..."** (bottom left)
3. Navigate to `Packages/CommuteTimelyAuth`
4. Select the folder and click **"Add Package"**
5. Select **"CommuteTimelyAuth"** and click **"Add Package"**

### Solution C: Manual Package.swift Link (Alternative)

If the above doesn't work, add the package to Tests targets too:

1. Select **CommuteTimely target** (under TARGETS)
2. Go to **"Build Phases"**
3. Expand **"Link Binary With Libraries"**
4. Click **"+"**
5. Select **"CommuteTimelyAuth"**
6. Click **"Add"**

Repeat for **CommuteTimelyTests** and **CommuteTimelyUITests** targets.

## Issue 2: Color Asset Conflicts ✅ FIXED

The color assets "Primary" and "Secondary" conflicted with SwiftUI symbols.

**What was done:**
- Renamed `Primary.colorset` → `BrandPrimary.colorset`
- Renamed `Secondary.colorset` → `BrandSecondary.colorset`
- Updated `DesignTokens.swift` to reference new names

**No further action needed** - the assets are renamed and code is updated.

## Issue 3: onChange Deprecation Warnings

All `onChange` calls have been updated to iOS 17+ syntax.

**If you still see warnings**, clean the build:
```bash
# In Xcode:
Product → Clean Build Folder (⇧⌘K)
```

Then rebuild:
```bash
Product → Build (⌘B)
```

## Issue 4: Main Actor Isolation in PremiumFeatureGate

The init method has been fixed to be `nonisolated`.

**If errors persist**, the solution is already in place. Just clean build.

## Complete Fix Checklist

- [x] Add CommuteTimelyAuth package to Xcode project (see Issue 1)
- [x] Clean build folder: `Product → Clean Build Folder` (⇧⌘K)
- [x] Rebuild: `Product → Build` (⌘B)
- [x] If still failing, restart Xcode

## Verification Steps

After adding the package:

1. **Clean Build Folder**: Product → Clean Build Folder (⇧⌘K)
2. **Build**: Product → Build (⌘B)
3. **Verify** no errors related to:
   - `Cannot find module dependency: 'CommuteTimelyAuth'`
   - Color asset conflicts
   - onChange deprecation
4. **Run**: Product → Run (⌘R)

## Expected Result

✅ Zero errors  
⚠️ Only the iOS 26 deprecation warnings (CLGeocoder) - these are safe to ignore

## Troubleshooting

### Package Still Not Found

If the package isn't being recognized:

1. **Check Package.swift exists**:
   ```bash
   ls -la /Users/apple/Desktop/xcode/CommuteTimely/Packages/CommuteTimelyAuth/Package.swift
   ```

2. **Verify in Xcode**:
   - Project Navigator → Show "Packages" folder
   - You should see "CommuteTimelyAuth" listed

3. **Reset Package Cache**:
   ```bash
   # File → Packages → Reset Package Caches
   ```

4. **Restart Xcode**:
   - Close Xcode completely
   - Reopen project
   - Try adding package again

### Build Errors Persist

1. **Delete Derived Data**:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/CommuteTimely-*
   ```

2. **Clean and Rebuild**:
   - Product → Clean Build Folder
   - Product → Build

3. **Check Import Statements**:
   All these files should have `import CommuteTimelyAuth`:
   - `CommuteTimely/App/DIContainer.swift`
   - `CommuteTimely/CommuteTimelyApp.swift`
   - `CommuteTimely/Features/Auth/*.swift`
   - `CommuteTimely/Features/Settings/SettingsView.swift`
   - `CommuteTimely/Features/Onboarding/OnboardingCoordinatorView.swift`

## Alternative: Test Without Package (Quick Fix)

If you need to test quickly without full auth:

1. Comment out auth-related code in DIContainer:
   ```swift
   // lazy var authManager: AuthManager = { ... }()
   ```

2. Use mock:
   ```swift
   lazy var authManager: Any = NSObject()
   ```

**Not recommended** - only for emergency testing.

## Success Indicators

When everything is working:

✅ Xcode shows "Build Succeeded"  
✅ Package "CommuteTimelyAuth" visible in Project Navigator  
✅ No errors about missing modules  
✅ Only warnings about iOS 26 deprecations (safe to ignore)  
✅ App runs on simulator without crashes

## Questions?

If issues persist after following all steps:

1. Check that Package.swift is valid: `swift build` in package directory
2. Verify Xcode version: 15.0+
3. Try creating a new scheme
4. Check Console.app for Xcode errors

---

**After completing these steps, the project should compile successfully!**

