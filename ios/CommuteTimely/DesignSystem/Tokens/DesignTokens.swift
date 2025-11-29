//
// DesignTokens.swift
// CommuteTimely
//
// Central design system with colors, typography, spacing, and animation tokens
//

import SwiftUI

enum DesignTokens {
    
    // MARK: - Colors
    
    enum Colors {
        // Primary Brand Colors
        static var primary: Color {
            Color("BrandPrimary", bundle: nil)
        }
        static var primaryLight: Color {
            Color("PrimaryLight", bundle: nil)
        }
        static var primaryDark: Color {
            Color("PrimaryDark", bundle: nil)
        }
        
        // Secondary Colors
        static var secondary: Color {
            Color("BrandSecondary", bundle: nil)
        }
        static var secondaryLight: Color {
            Color("SecondaryLight", bundle: nil)
        }
        
        // Semantic Colors
        static let success = Color("Success", bundle: nil)
        static let warning = Color("Warning", bundle: nil)
        static let error = Color("Error", bundle: nil)
        static let info = Color("Info", bundle: nil)
        
        // Traffic Colors
        static let trafficClear = Color.green
        static let trafficLight = Color.yellow
        static let trafficModerate = Color.orange
        static let trafficHeavy = Color.red
        static let trafficSevere = Color(red: 0.55, green: 0, blue: 0)
        
        // Neutral Colors
        static var background: Color {
            Color("Background", bundle: nil)
        }
        static var surface: Color {
            Color("Surface", bundle: nil)
        }
        static var surfaceElevated: Color {
            Color("SurfaceElevated", bundle: nil)
        }
        
        // Text Colors
        static var textPrimary: Color {
            Color("TextPrimary", bundle: nil)
        }
        static var textSecondary: Color {
            Color("TextSecondary", bundle: nil)
        }
        static var textTertiary: Color {
            Color("TextTertiary", bundle: nil)
        }
        
        // Border & Divider
        static var border: Color {
            Color("Border", bundle: nil)
        }
        static var divider: Color {
            Color("Divider", bundle: nil)
        }
        
        // MARK: - Compatibility
        
        /// Fallback method for primary color access
        /// Used throughout the codebase for backwards compatibility
        static func primaryFallback() -> Color {
            primary
        }
        
        /// Fallback method for secondary color access
        static func secondaryFallback() -> Color {
            secondary
        }
    }
    
    // MARK: - Typography
    
    enum Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyBold = Font.system(size: 17, weight: .semibold, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let captionBold = Font.system(size: 12, weight: .semibold, design: .default)
        
        // Dynamic Type support
        static let dynamicTitle1 = Font.system(.title, design: .rounded).weight(.bold)
        static let dynamicTitle2 = Font.system(.title2, design: .rounded).weight(.semibold)
        static let dynamicTitle3 = Font.system(.title3, design: .rounded).weight(.semibold)
        static let dynamicHeadline = Font.system(.headline, design: .rounded)
        static let dynamicBody = Font.system(.body, design: .default)
        static let dynamicCallout = Font.system(.callout, design: .default)
        static let dynamicSubheadline = Font.system(.subheadline, design: .default)
        static let dynamicFootnote = Font.system(.footnote, design: .default)
        static let dynamicCaption = Font.system(.caption, design: .default)
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let round: CGFloat = 999 // Fully rounded
    }
    
    // MARK: - Shadows
    
    enum Shadow {
        static let small = (color: Color.black.opacity(0.1), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let medium = (color: Color.black.opacity(0.15), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        static let large = (color: Color.black.opacity(0.2), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
    }
    
    // MARK: - Animation
    
    enum Animation {
        // Quick animations for micro-interactions
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        
        // Standard animations for common transitions
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        
        // Slow animations for major transitions
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        
        // Refined spring animations with tuned values
        static let spring = SwiftUI.Animation.spring(
            response: 0.4,
            dampingFraction: 0.8,
            blendDuration: 0.1
        )
        
        static let springBouncy = SwiftUI.Animation.spring(
            response: 0.5,
            dampingFraction: 0.7,
            blendDuration: 0.15
        )
        
        static let springSmooth = SwiftUI.Animation.spring(
            response: 0.35,
            dampingFraction: 0.85,
            blendDuration: 0.1
        )
        
        // Legacy support
        static let bouncy = SwiftUI.Animation.interpolatingSpring(stiffness: 200, damping: 15)
        
        // Respect Reduce Motion
        static func adaptive(_ animation: SwiftUI.Animation) -> SwiftUI.Animation {
            if UIAccessibility.isReduceMotionEnabled {
                return .easeInOut(duration: 0.2)
            }
            return animation
        }
    }
    
    // MARK: - Sizing
    
    enum Size {
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 24
        static let iconLarge: CGFloat = 32
        static let iconXLarge: CGFloat = 48
        
        static let buttonHeight: CGFloat = 50
        static let buttonHeightCompact: CGFloat = 40
        static let textFieldHeight: CGFloat = 48
        
        static let cardMinHeight: CGFloat = 100
        static let mapPinSize: CGFloat = 40
    }
    
    // MARK: - Opacity
    
    enum Opacity {
        static let disabled: Double = 0.4
        static let secondary: Double = 0.7
        static let overlay: Double = 0.6
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        self
            .background(DesignTokens.Colors.surface)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .shadow(
                color: DesignTokens.Shadow.medium.color,
                radius: DesignTokens.Shadow.medium.radius,
                x: DesignTokens.Shadow.medium.x,
                y: DesignTokens.Shadow.medium.y
            )
    }
    
    func elevatedCardStyle() -> some View {
        self
            .background(DesignTokens.Colors.surfaceElevated)
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .shadow(
                color: DesignTokens.Shadow.large.color,
                radius: DesignTokens.Shadow.large.radius,
                x: DesignTokens.Shadow.large.x,
                y: DesignTokens.Shadow.large.y
            )
    }
    
    // Accessibility helpers
    func accessibleButton(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
    
    func accessibleMapHint() -> some View {
        self
            .accessibilityHint("Drag to move the map, pinch to zoom")
    }
    
    // Respect Reduce Motion
    func respectsReduceMotion() -> some View {
        self
            .animation(DesignTokens.Animation.adaptive(DesignTokens.Animation.standard), value: UUID())
    }
}

