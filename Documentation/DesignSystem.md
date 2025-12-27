# Design System

CommuteTimely uses a comprehensive design system with consistent colors, typography, spacing, and components.

## Design Tokens

All design tokens are defined in `DesignTokens.swift`:

```swift
enum DesignTokens {
    enum Colors { ... }
    enum Typography { ... }
    enum Spacing { ... }
    enum CornerRadius { ... }
    enum Shadow { ... }
    enum Animation { ... }
    enum Size { ... }
    enum Opacity { ... }
}
```

## Colors

### Primary Colors

- **BrandPrimary**: Main brand color (from asset catalog)
- **PrimaryLight**: Light variant
- **PrimaryDark**: Dark variant

### Secondary Colors

- **BrandSecondary**: Secondary brand color
- **SecondaryLight**: Light variant

### Semantic Colors

- **Success**: Green for success states
- **Warning**: Yellow/orange for warnings
- **Error**: Red for errors
- **Info**: Blue for informational messages

### Traffic Colors

- **trafficClear**: Green (no traffic)
- **trafficLight**: Yellow (light traffic)
- **trafficModerate**: Orange (moderate traffic)
- **trafficHeavy**: Red (heavy traffic)
- **trafficSevere**: Dark red (severe traffic)

### Neutral Colors

- **Background**: App background color
- **Surface**: Card/surface background
- **SurfaceElevated**: Elevated surface (modals, sheets)
- **Border**: Border color
- **Divider**: Divider color

### Text Colors

- **textPrimary**: Primary text color
- **textSecondary**: Secondary text color
- **textTertiary**: Tertiary text color

### Usage

```swift
Text("Hello")
    .foregroundColor(DesignTokens.Colors.textPrimary)

Rectangle()
    .fill(DesignTokens.Colors.primaryFallback())
```

### Color Assets

Colors are defined in `Assets.xcassets`:
- `BrandPrimary.colorset`
- `BrandSecondary.colorset`
- `Background.colorset`
- `Surface.colorset`
- `TextPrimary.colorset`
- etc.

## Typography

### Font Sizes

- **largeTitle**: 34pt, bold, rounded
- **title1**: 28pt, bold, rounded
- **title2**: 22pt, semibold, rounded
- **title3**: 20pt, semibold, rounded
- **headline**: 17pt, semibold, rounded
- **body**: 17pt, regular, default
- **bodyBold**: 17pt, semibold, default
- **callout**: 16pt, regular, default
- **subheadline**: 15pt, regular, default
- **footnote**: 13pt, regular, default
- **caption**: 12pt, regular, default
- **captionBold**: 12pt, semibold, default

### Dynamic Type

All typography supports Dynamic Type:

```swift
static let dynamicTitle1 = Font.system(.title, design: .rounded).weight(.bold)
static let dynamicBody = Font.system(.body, design: .default)
```

### Usage

```swift
Text("Title")
    .font(DesignTokens.Typography.title1)

Text("Body")
    .font(DesignTokens.Typography.body)
```

## Spacing

### Spacing Scale

- **xxs**: 2pt
- **xs**: 4pt
- **sm**: 8pt
- **md**: 16pt
- **lg**: 24pt
- **xl**: 32pt
- **xxl**: 48pt
- **xxxl**: 64pt

### Usage

```swift
VStack(spacing: DesignTokens.Spacing.md) {
    // Content
}
.padding(DesignTokens.Spacing.lg)
```

## Corner Radius

### Radius Scale

- **xs**: 4pt
- **sm**: 8pt
- **md**: 12pt
- **lg**: 16pt
- **xl**: 24pt
- **round**: 999pt (fully rounded)

### Usage

```swift
RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
```

## Shadows

### Shadow Presets

- **small**: 4pt radius, 2pt offset, 10% opacity
- **medium**: 8pt radius, 4pt offset, 15% opacity
- **large**: 16pt radius, 8pt offset, 20% opacity

### Usage

```swift
.shadow(
    color: DesignTokens.Shadow.medium.color,
    radius: DesignTokens.Shadow.medium.radius,
    x: DesignTokens.Shadow.medium.x,
    y: DesignTokens.Shadow.medium.y
)
```

## Animation

### Animation Presets

- **quick**: 0.2s ease-in-out (micro-interactions)
- **standard**: 0.3s ease-in-out (common transitions)
- **slow**: 0.5s ease-in-out (major transitions)
- **spring**: 0.4s response, 0.8 damping (smooth)
- **springBouncy**: 0.5s response, 0.7 damping (bouncy)
- **springSmooth**: 0.35s response, 0.85 damping (very smooth)

### Adaptive Animation

Respects Reduce Motion setting:

```swift
static func adaptive(_ animation: SwiftUI.Animation) -> SwiftUI.Animation {
    if UIAccessibility.isReduceMotionEnabled {
        return .easeInOut(duration: 0.2)
    }
    return animation
}
```

### Usage

```swift
.animation(DesignTokens.Animation.adaptive(DesignTokens.Animation.springSmooth))
```

## Sizing

### Icon Sizes

- **iconSmall**: 16pt
- **iconMedium**: 24pt
- **iconLarge**: 32pt
- **iconXLarge**: 48pt

### Component Sizes

- **buttonHeight**: 50pt
- **buttonHeightCompact**: 40pt
- **textFieldHeight**: 48pt
- **cardMinHeight**: 100pt
- **mapPinSize**: 40pt

### Usage

```swift
Image(systemName: "star")
    .font(.system(size: DesignTokens.Size.iconMedium))
```

## Opacity

### Opacity Values

- **disabled**: 0.4 (disabled state)
- **secondary**: 0.7 (secondary content)
- **overlay**: 0.6 (overlays)

### Usage

```swift
.opacity(DesignTokens.Opacity.disabled)
```

## Components

### CTButton

Reusable button component:

```swift
CTButton("Save", style: .primary) {
    // Action
}
```

**Styles:**
- `.primary`: Primary action
- `.secondary`: Secondary action
- `.destructive`: Destructive action

### CTCard

Card component:

```swift
CTCard {
    // Content
}
```

### CTTextField

Text field component:

```swift
CTTextField("Enter text", text: $text)
```

### TripListCell

Trip list cell component:

```swift
TripListCell(
    trip: trip,
    onToggle: { isActive in ... },
    onTap: { ... }
)
```

## View Extensions

### Card Style

```swift
.cardStyle()
```

Applies:
- Surface background
- Medium corner radius
- Medium shadow

### Elevated Card Style

```swift
.elevatedCardStyle()
```

Applies:
- Elevated surface background
- Large corner radius
- Large shadow

### Accessibility Helpers

```swift
.accessibleButton(label: "Save", hint: "Saves the trip")
.accessibleMapHint()
```

### Reduce Motion

```swift
.respectsReduceMotion()
```

## Light/Dark Mode

### Color Adaptation

All colors automatically adapt to light/dark mode via asset catalog:

```swift
Color("TextPrimary", bundle: nil)
```

Asset catalog defines:
- Light mode color
- Dark mode color

### Theme Support

Three theme options:
- **Light**: Always light mode
- **Dark**: Always dark mode
- **System**: Follows system setting

### Theme Application

```swift
.applyTheme(themeManager)
```

Applied at root view level.

## Component Patterns

### Cards

- Use `CTCard` or `.cardStyle()` modifier
- Consistent padding and spacing
- Medium corner radius
- Medium shadow

### Buttons

- Use `CTButton` component
- Consistent height (50pt)
- Primary, secondary, destructive styles
- Accessible labels

### Modals

- Use `.sheet()` modifier
- Elevated surface background
- Large corner radius
- Dismissible

### Lists

- Use `List` or `ScrollView` with `LazyVStack`
- Consistent cell heights
- Proper spacing
- Swipe actions

## Accessibility

### Dynamic Type

All text supports Dynamic Type:

```swift
.font(DesignTokens.Typography.dynamicBody)
```

### VoiceOver

- All interactive elements have labels
- Hints provided where needed
- Proper accessibility traits

### Reduce Motion

- Animations respect Reduce Motion
- Use `.adaptive()` modifier
- Provide static alternatives

## Best Practices

### Color Usage

- Use semantic colors for states
- Use primary colors for branding
- Use neutral colors for backgrounds

### Typography

- Use appropriate font sizes
- Support Dynamic Type
- Use rounded design for headings

### Spacing

- Use spacing scale consistently
- Maintain visual rhythm
- Group related content

### Animation

- Use appropriate animation speed
- Respect Reduce Motion
- Provide feedback for interactions

