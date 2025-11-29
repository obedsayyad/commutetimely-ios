# Theme System Documentation

Guide to using and extending the CommuteTimely theme system.

## Overview

CommuteTimely uses a comprehensive theme system supporting light, dark, and system-automatic modes.

## Architecture

### ThemeManager

Central theme controller:
```swift
@StateObject var themeManager = DIContainer.shared.themeManager

// Apply theme to view hierarchy
.applyTheme(themeManager)
```

### Theme Modes

```swift
enum ThemeMode: String {
    case system  // Follow system appearance
    case light   // Always light
    case dark    // Always dark
}
```

## Using Themes

### Setting Theme

```swift
// From user selection
themeManager.setTheme(.dark)

// Toggle through modes
themeManager.toggleTheme()

// In Settings
Picker("Theme", selection: $themeManager.currentTheme) {
    ForEach(ThemeMode.allCases) { mode in
        Text(mode.displayName).tag(mode)
    }
}
```

### Applying Theme

**App-wide:**
```swift
WindowGroup {
    ContentView()
        .applyTheme(themeManager)
}
```

**Per-view:**
```swift
SomeView()
    .preferredColorScheme(themeManager.currentTheme.colorScheme)
```

## Color System

### Semantic Colors

All colors adapt automatically to light/dark mode:

```swift
// Text colors
DesignTokens.Colors.textPrimary    // Main text
DesignTokens.Colors.textSecondary  // Secondary text
DesignTokens.Colors.textTertiary   // Tertiary text

// Background colors
DesignTokens.Colors.background     // Main background
DesignTokens.Colors.surface        // Card/surface background
DesignTokens.Colors.surfaceElevated // Elevated surfaces

// Brand colors
DesignTokens.Colors.primary        // Primary brand color
DesignTokens.Colors.secondary      // Secondary brand color

// Semantic colors
DesignTokens.Colors.success        // Success states
DesignTokens.Colors.error          // Error states
DesignTokens.Colors.warning        // Warning states
DesignTokens.Colors.info           // Info states

// UI colors
DesignTokens.Colors.border         // Borders
DesignTokens.Colors.divider        // Dividers
```

### Adding New Colors

1. **Create Color Set in Assets:**
   - Right-click `Assets.xcassets`
   - New Color Set
   - Name it descriptively (e.g., "AccentHover")

2. **Configure Appearances:**
   - Select color set
   - In Attributes Inspector: Appearances → Add "Dark"
   - Set light mode color
   - Set dark mode color

3. **Add to DesignTokens:**
```swift
enum Colors {
    static var accentHover: Color {
        Color("AccentHover")
    }
}
```

### Color Guidelines

**Light Mode Values:**
- Backgrounds: Light grays (#F9F9F9 - #FFFFFF)
- Text: Dark grays (#1C1C1C - #666666)
- Borders: Light grays (#E0E0E0)

**Dark Mode Values:**
- Backgrounds: Dark grays (#1C1C1C - #2C2C2C)
- Text: Light grays (#E0E0E0 - #FFFFFF)
- Borders: Medium grays (#3C3C3C)

**Contrast Ratios:**
- Text on background: minimum 4.5:1
- Large text: minimum 3:1
- UI elements: minimum 3:1

## Asset Catalog Structure

```
Assets.xcassets/
├── Colors/
│   ├── Background.colorset/
│   │   └── Contents.json (with light/dark variants)
│   ├── Primary.colorset/
│   ├── TextPrimary.colorset/
│   └── ...
└── Images/
    └── ...
```

## Dynamic Type Support

All text uses Dynamic Type:

```swift
// Prefer dynamic typography
Text("Title")
    .font(DesignTokens.Typography.dynamicTitle1)

// Fixed sizes when needed
Text("Badge")
    .font(DesignTokens.Typography.caption)
```

### Dynamic Type Scale

- `.dynamicTitle1` through `.dynamicCaption`
- Automatically scales with user preferences
- Test with Settings → Accessibility → Display & Text Size

## Testing Themes

### Manual Testing

1. **Light Mode:**
   - Settings → Display & Brightness → Light
   - Verify all screens render correctly
   - Check contrast ratios

2. **Dark Mode:**
   - Settings → Display & Brightness → Dark
   - Verify colors adapt properly
   - Check no white flashes

3. **Automatic:**
   - Settings → Display & Brightness → Automatic
   - Change system time to trigger mode switch
   - Verify smooth transitions

### Accessibility Testing

**VoiceOver:**
```bash
# Enable VoiceOver
Settings → Accessibility → VoiceOver → On
```

**Color Blindness:**
- Settings → Accessibility → Display & Text Size
- Test with Color Filters enabled

**Reduce Motion:**
- Respect `UIAccessibility.isReduceMotionEnabled`
- Use `.animation(nil)` conditionally

## Best Practices

### Do's

✅ Always use semantic color names
✅ Test both light and dark modes
✅ Support system automatic mode
✅ Use Dynamic Type for text
✅ Check accessibility contrast

### Don'ts

❌ Don't hardcode color values
❌ Don't use `.color(Color(red:green:blue:))`
❌ Don't ignore system color scheme
❌ Don't use fixed text sizes (except badges/icons)
❌ Don't forget to test on device

## Custom Themes (Future)

To add user-customizable themes:

1. **Extend ThemeMode:**
```swift
enum ThemeMode {
    case system
    case light
    case dark
    case custom(CustomTheme)
}

struct CustomTheme {
    let primary: Color
    let background: Color
    // ...
}
```

2. **Update ThemeManager:**
```swift
func setCustomTheme(_ theme: CustomTheme) {
    currentTheme = .custom(theme)
}
```

3. **Store preferences:**
```swift
UserDefaults.standard.set(encodedTheme, forKey: "custom_theme")
```

## Debugging

### Color not changing?

1. Check color asset has dark appearance
2. Verify using `DesignTokens.Colors.*`
3. Confirm `.applyTheme()` is in view hierarchy
4. Check `preferredColorScheme` isn't overridden

### Theme not persisting?

1. Verify `ThemeManager` uses `@AppStorage`
2. Check UserDefaults not cleared
3. Confirm `ThemeManager` is @StateObject

## Performance

### Optimization Tips

- Color calculations cached by system
- Asset loading optimized by iOS
- Theme switches handled efficiently
- No manual color recalculations needed

### Avoid:
```swift
// Bad - recalculates on every render
.foregroundColor(someCondition ? .red : .blue)

// Good - use semantic color
.foregroundColor(DesignTokens.Colors.error)
```

## Migration

### From Hardcoded Colors

**Before:**
```swift
Text("Hello")
    .foregroundColor(.black)
    .background(Color(red: 0.9, green: 0.9, blue: 0.9))
```

**After:**
```swift
Text("Hello")
    .foregroundColor(DesignTokens.Colors.textPrimary)
    .background(DesignTokens.Colors.surface)
```

## Additional Resources

- [Apple HIG - Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
- [WCAG Contrast Guidelines](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html)
- [SF Symbols](https://developer.apple.com/sf-symbols/)

