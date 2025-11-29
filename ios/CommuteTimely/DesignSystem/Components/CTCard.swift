//
// CTCard.swift
// CommuteTimely
//
// Reusable card component with consistent styling
//

import SwiftUI

struct CTCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let elevation: CardElevation
    
    init(
        padding: CGFloat = DesignTokens.Spacing.md,
        elevation: CardElevation = .medium,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.elevation = elevation
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(DesignTokens.Colors.surface)
            .cornerRadius(elevation.cornerRadius)
            .shadow(
                color: elevation.shadowColor,
                radius: elevation.shadowRadius,
                x: 0,
                y: elevation.shadowY
            )
    }
    
    enum CardElevation {
        case low
        case medium
        case high
        
        var cornerRadius: CGFloat {
            switch self {
            case .low: return DesignTokens.CornerRadius.sm
            case .medium: return DesignTokens.CornerRadius.md
            case .high: return DesignTokens.CornerRadius.lg
            }
        }
        
        var shadowColor: Color {
            Color.black.opacity(0.1)
        }
        
        var shadowRadius: CGFloat {
            switch self {
            case .low: return 4
            case .medium: return 8
            case .high: return 16
            }
        }
        
        var shadowY: CGFloat {
            switch self {
            case .low: return 2
            case .medium: return 4
            case .high: return 8
            }
        }
    }
}

// MARK: - Interactive Card

struct CTInteractiveCard<Content: View>: View {
    let content: Content
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            content
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.surface)
                .cornerRadius(DesignTokens.CornerRadius.md)
                .shadow(
                    color: Color.black.opacity(isPressed ? 0.05 : 0.1),
                    radius: isPressed ? 4 : 8,
                    x: 0,
                    y: isPressed ? 2 : 4
                )
                .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(DesignTokens.Animation.adaptive(DesignTokens.Animation.quick)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(DesignTokens.Animation.adaptive(DesignTokens.Animation.quick)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Info Card

struct CTInfoCard: View {
    let title: String
    let message: String
    let icon: String
    let style: InfoStyle
    
    init(
        title: String,
        message: String,
        icon: String,
        style: InfoStyle = .info
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.style = style
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DesignTokens.Size.iconMedium, weight: .semibold))
                .foregroundColor(style.iconColor)
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text(message)
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(style.backgroundColor)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(style.borderColor, lineWidth: 1)
        )
    }
    
    enum InfoStyle {
        case info
        case success
        case warning
        case error
        
        var backgroundColor: Color {
            switch self {
            case .info: return Color.blue.opacity(0.1)
            case .success: return Color.green.opacity(0.1)
            case .warning: return Color.orange.opacity(0.1)
            case .error: return Color.red.opacity(0.1)
            }
        }
        
        var borderColor: Color {
            switch self {
            case .info: return Color.blue.opacity(0.3)
            case .success: return Color.green.opacity(0.3)
            case .warning: return Color.orange.opacity(0.3)
            case .error: return Color.red.opacity(0.3)
            }
        }
        
        var iconColor: Color {
            switch self {
            case .info: return Color.blue
            case .success: return Color.green
            case .warning: return Color.orange
            case .error: return Color.red
            }
        }
    }
}

#Preview("Cards") {
    VStack(spacing: 16) {
        CTCard {
            Text("Basic Card")
                .font(DesignTokens.Typography.body)
        }
        
        CTInfoCard(
            title: "Tip",
            message: "Leave 15 minutes earlier to avoid traffic",
            icon: "lightbulb.fill",
            style: .info
        )
        
        CTInteractiveCard(action: {}) {
            Text("Interactive Card")
        }
    }
    .padding()
    .background(DesignTokens.Colors.background)
}

