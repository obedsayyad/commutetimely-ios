//
// HapticManager.swift
// CommuteTimely
//
// Centralized manager for premium haptic feedback
//

import UIKit

final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // MARK: - Impact Feedback
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // MARK: - Notification Feedback
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    // MARK: - Selection Feedback
    
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    // MARK: - Custom Patterns (Premium Feel)
    
    /// A satisfying "thud" for locking in a major choice
    func successConfirm() {
        impact(style: .heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impact(style: .medium)
        }
    }
    
    /// A subtle warning vibration
    func warning() {
        notification(type: .warning)
    }
    
    /// A strong error vibration
    func error() {
        notification(type: .error)
    }
    
    /// Light tap for standard interactions
    func tap() {
        impact(style: .light)
    }
}
