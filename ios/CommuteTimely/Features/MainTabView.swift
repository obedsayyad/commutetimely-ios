//
// MainTabView.swift
// CommuteTimely
//
// Main tab bar interface
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TripListView()
                .tabItem {
                    Label("Trips", systemImage: "list.bullet")
                }
                .tag(0)
                .accessibilityLabel("Trips tab")
            
            MapScreen()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(1)
                .accessibilityLabel("Map tab")
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
                .accessibilityLabel("Settings tab")
        }
        .tint(DesignTokens.Colors.primaryFallback())
        .animation(DesignTokens.Animation.adaptive(DesignTokens.Animation.quick), value: selectedTab)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppCoordinator(services: DIContainer.shared))
}

