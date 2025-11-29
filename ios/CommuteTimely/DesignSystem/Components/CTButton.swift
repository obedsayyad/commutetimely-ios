//
// CTButton.swift
// CommuteTimely
//
// Custom button component with multiple styles and loading state
//

import SwiftUI

struct CTButton: View {
    let title: String
    let style: ButtonStyle
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    init(
        _ title: String,
        style: ButtonStyle = .primary,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.textColor))
                        .scaleEffect(0.9)
                } else {
                    Text(title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(style.textColor)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignTokens.Size.buttonHeight)
            .background(style.backgroundColor)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(style.borderColor, lineWidth: style.borderWidth)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? DesignTokens.Opacity.disabled : 1.0)
        .accessibilityLabel(title)
        .accessibilityHint(isLoading ? "Loading" : "")
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isDisabled && !isLoading {
                        withAnimation(DesignTokens.Animation.adaptive(DesignTokens.Animation.quick)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(DesignTokens.Animation.adaptive(DesignTokens.Animation.quick)) {
                        isPressed = false
                    }
                }
        )
    }
    
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        case outline
        case text
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                return DesignTokens.Colors.primaryFallback()
            case .secondary:
                return DesignTokens.Colors.secondaryFallback()
            case .destructive:
                return Color.red
            case .outline:
                return Color.clear
            case .text:
                return Color.clear
            }
        }
        
        var textColor: Color {
            switch self {
            case .primary, .secondary, .destructive:
                return .white
            case .outline:
                return DesignTokens.Colors.primaryFallback()
            case .text:
                return DesignTokens.Colors.primaryFallback()
            }
        }
        
        var borderColor: Color {
            switch self {
            case .outline:
                return DesignTokens.Colors.primaryFallback()
            default:
                return Color.clear
            }
        }
        
        var borderWidth: CGFloat {
            switch self {
            case .outline:
                return 2
            default:
                return 0
            }
        }
    }
}

// MARK: - Compact Button

struct CTButtonCompact: View {
    let title: String
    let icon: String?
    let style: CTButton.ButtonStyle
    let action: () -> Void
    
    init(
        _ title: String,
        icon: String? = nil,
        style: CTButton.ButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(DesignTokens.Typography.callout)
            }
            .foregroundColor(style.textColor)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(style.backgroundColor)
            .cornerRadius(DesignTokens.CornerRadius.sm)
        }
    }
}

// MARK: - Icon Button

struct CTIconButton: View {
    let icon: String
    let style: IconButtonStyle
    let action: () -> Void
    
    init(
        icon: String,
        style: IconButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: style.iconSize, weight: .semibold))
                .foregroundColor(style.tintColor)
                .frame(width: style.size, height: style.size)
                .background(style.backgroundColor)
                .cornerRadius(style.cornerRadius)
        }
        .accessibilityLabel(icon)
    }
    
    enum IconButtonStyle {
        case primary
        case secondary
        case ghost
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                return DesignTokens.Colors.primaryFallback()
            case .secondary:
                return DesignTokens.Colors.secondaryFallback()
            case .ghost:
                return Color.clear
            }
        }
        
        var tintColor: Color {
            switch self {
            case .primary, .secondary:
                return .white
            case .ghost:
                return DesignTokens.Colors.primaryFallback()
            }
        }
        
        var size: CGFloat { 44 }
        var iconSize: CGFloat { 20 }
        var cornerRadius: CGFloat { DesignTokens.CornerRadius.sm }
    }
}

#Preview("Primary Button") {
    VStack(spacing: 16) {
        CTButton("Continue", style: .primary) {}
        CTButton("Loading", style: .primary, isLoading: true) {}
        CTButton("Disabled", style: .primary, isDisabled: true) {}
    }
    .padding()
}

#Preview("Button Styles") {
    VStack(spacing: 16) {
        CTButton("Primary", style: .primary) {}
        CTButton("Secondary", style: .secondary) {}
        CTButton("Destructive", style: .destructive) {}
        CTButton("Outline", style: .outline) {}
        CTButton("Text", style: .text) {}
    }
    .padding()
}

