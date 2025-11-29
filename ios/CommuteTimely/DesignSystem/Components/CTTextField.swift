//
// CTTextField.swift
// CommuteTimely
//
// Custom text field component with validation and styling
//

import SwiftUI

struct CTTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let keyboardType: UIKeyboardType
    let validation: ValidationState
    let validationMessage: String?
    
    @FocusState private var isFocused: Bool
    
    init(
        title: String = "",
        placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        keyboardType: UIKeyboardType = .default,
        validation: ValidationState = .none,
        validationMessage: String? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.keyboardType = keyboardType
        self.validation = validation
        self.validationMessage = validationMessage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            if !title.isEmpty {
                Text(title)
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            
            HStack(spacing: DesignTokens.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: DesignTokens.Size.iconSmall))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                
                TextField(placeholder, text: $text)
                    .font(DesignTokens.Typography.body)
                    .keyboardType(keyboardType)
                    .focused($isFocused)
                    .autocorrectionDisabled()
                
                if validation != .none {
                    Image(systemName: validation.icon)
                        .font(.system(size: DesignTokens.Size.iconSmall))
                        .foregroundColor(validation.color)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.surface)
            .cornerRadius(DesignTokens.CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .stroke(borderColor, lineWidth: 2)
            )
            
            if let message = validationMessage, validation != .none {
                Text(message)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(validation.color)
            }
        }
        .animation(DesignTokens.Animation.quick, value: isFocused)
        .animation(DesignTokens.Animation.quick, value: validation)
    }
    
    private var borderColor: Color {
        if isFocused {
            return DesignTokens.Colors.primaryFallback()
        }
        switch validation {
        case .valid:
            return Color.green
        case .invalid:
            return Color.red
        case .none:
            return Color.clear
        }
    }
    
    enum ValidationState {
        case none
        case valid
        case invalid
        
        var icon: String {
            switch self {
            case .none: return ""
            case .valid: return "checkmark.circle.fill"
            case .invalid: return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .none: return .clear
            case .valid: return .green
            case .invalid: return .red
            }
        }
    }
}

// MARK: - Secure Text Field

struct CTSecureTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    @State private var isSecure = true
    @FocusState private var isFocused: Bool
    
    init(
        title: String = "",
        placeholder: String,
        text: Binding<String>
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            if !title.isEmpty {
                Text(title)
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "lock.fill")
                    .font(.system(size: DesignTokens.Size.iconSmall))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .font(DesignTokens.Typography.body)
                        .focused($isFocused)
                } else {
                    TextField(placeholder, text: $text)
                        .font(DesignTokens.Typography.body)
                        .focused($isFocused)
                }
                
                Button(action: { isSecure.toggle() }) {
                    Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: DesignTokens.Size.iconSmall))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.surface)
            .cornerRadius(DesignTokens.CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .stroke(
                        isFocused ? DesignTokens.Colors.primaryFallback() : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .animation(DesignTokens.Animation.quick, value: isFocused)
    }
}

#Preview("Text Fields") {
    VStack(spacing: 24) {
        CTTextField(
            title: "Email",
            placeholder: "Enter your email",
            text: .constant(""),
            icon: "envelope.fill",
            keyboardType: .emailAddress
        )
        
        CTTextField(
            title: "Destination",
            placeholder: "Search for a place",
            text: .constant("123 Main St"),
            icon: "mappin.circle.fill",
            validation: .valid,
            validationMessage: "Valid address"
        )
        
        CTSecureTextField(
            title: "Password",
            placeholder: "Enter password",
            text: .constant("")
        )
    }
    .padding()
    .background(DesignTokens.Colors.background)
}

