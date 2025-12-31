//
//  AppDelegate.swift
//  CommuteTimely
//
//  Handles application lifecycle events and Quick Actions.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    
    // Handle Cold Launch via Quick Action
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Check for shortcut item in connection options
        if let shortcutItem = options.shortcutItem {
            ShortcutHandler.shared.handle(shortcutItem)
        }
        
        // Return default configuration. 
        // We use "Default Configuration" as that is what Xcode's generated Info.plist uses.
        // If this fails, we might need to inspect the Info.plist.
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = nil // Let SwiftUI handle the delegate
        return config
    }
    
    // Handle Warm Launch via Quick Action (fallback)
    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        ShortcutHandler.shared.handle(shortcutItem)
        completionHandler(true)
    }
}

// MARK: - Shortcut Handler

class ShortcutHandler {
    static let shared = ShortcutHandler()
    
    func handle(_ item: UIApplicationShortcutItem) {
        // Only handle the report bug action
        if item.type == "com.commutetimely.reportbug" {
            let email = "umerpatel1540@gmail.com"
            let subject = "Reporting for bugs/issues"
            let urlString = "mailto:\(email)?subject=\(subject)"
            
            if let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
                // Add a small delay for cold launch scenario so app is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}
