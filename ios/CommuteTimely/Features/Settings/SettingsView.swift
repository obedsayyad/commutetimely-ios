//
// SettingsView.swift
// CommuteTimely
//
// Settings and preferences screen
//

import SwiftUI
import Combine

struct SettingsView: View {
    @StateObject private var viewModel = DIContainer.shared.makeSettingsViewModel()
    @State private var showingAuthLanding = false
    @State private var showingThemePicker = false
    @State private var showingTemperaturePicker = false
    @State private var showingDistancePicker = false

    @ObservedObject var themeManager = DIContainer.shared.themeManager
    @ObservedObject var authManager = DIContainer.shared.authManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Account Section
                    accountSection
                    
                    // Subscription Section
                    if authManager.isAuthenticated {
                        subscriptionSection
                    }
                    
                    // Notifications Section
                    notificationsSection
                    
                    // Appearance Section
                    appearanceSection
                    
                    // Privacy Section
                    privacySection
                    
                    // Display Section
                    displaySection
                    
                    // About Section
                    aboutSection
                    

                }
                .padding(.vertical, DesignTokens.Spacing.md)
            }
            .background(DesignTokens.Colors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingAuthLanding) {
                AuthLandingView(authManager: authManager)
            }
            .sheet(isPresented: $showingThemePicker) {
                ThemePickerSheet(selectedTheme: $themeManager.currentTheme)
            }
            .sheet(isPresented: $showingTemperaturePicker) {
                TemperatureUnitPickerSheet(selectedUnit: $viewModel.preferences.displaySettings.temperatureUnit)
            }
            .sheet(isPresented: $showingDistancePicker) {
                DistanceUnitPickerSheet(selectedUnit: $viewModel.preferences.displaySettings.distanceUnit)
            }

            .alert("Notification Permission Required", isPresented: $viewModel.showPermissionAlert) {
                Button("Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("I need notification permission to send you personalized daily reminders. You can enable this in Settings.")
            }
        }
        .applyTheme(themeManager)
        .onAppear {
            viewModel.onAppear()
        }
        .onChange(of: viewModel.preferences) { _, _ in
            viewModel.savePreferences()
        }
    }
    
    // MARK: - Section Views
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Account")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.md)
            
            CTCard(padding: DesignTokens.Spacing.md, elevation: .medium) {
                ProfileAuthView(authManager: authManager)
                
                if !authManager.isAuthenticated {
                    Button {
                        showingAuthLanding = true
                    } label: {
                        HStack {
                            Text("Sign in to sync your trips")
                                .font(DesignTokens.Typography.callout)
                                .foregroundColor(DesignTokens.Colors.primaryFallback())
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.sm)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
    }
    
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("CommuteTimely Pro")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.md)
            
            CTCard(padding: DesignTokens.Spacing.md, elevation: .medium) {
                VStack(spacing: DesignTokens.Spacing.md) {
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            HStack(spacing: DesignTokens.Spacing.xs) {
                                Text(viewModel.subscriptionStatus.subscriptionTier.displayName)
                                    .font(DesignTokens.Typography.title3)
                                
                                if viewModel.subscriptionStatus.isSubscribed {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(DesignTokens.Colors.success)
                                        .font(.caption)
                                }
                            }
                            
                            if viewModel.subscriptionStatus.isSubscribed {
                                if viewModel.subscriptionStatus.isTrialing {
                                    Text("Trial active")
                                        .font(DesignTokens.Typography.caption)
                                        .foregroundColor(DesignTokens.Colors.info)
                                } else {
                                    Text("Active subscription")
                                        .font(DesignTokens.Typography.caption)
                                        .foregroundColor(DesignTokens.Colors.textSecondary)
                                }
                                
                                if let expirationDate = viewModel.subscriptionStatus.expirationDate {
                                    Text("Renews \(formatDate(expirationDate))")
                                        .font(DesignTokens.Typography.caption)
                                        .foregroundColor(DesignTokens.Colors.textTertiary)
                                }
                            } else {
                                Text("Limited to \(viewModel.subscriptionStatus.subscriptionTier.maxTrips) trips")
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        if !viewModel.subscriptionStatus.isSubscribed {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                Text("Coming Soon")
                                    .font(DesignTokens.Typography.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .background(DesignTokens.Colors.primaryFallback().opacity(0.5))
                            .cornerRadius(DesignTokens.CornerRadius.md)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            
            if !viewModel.subscriptionStatus.isSubscribed {
                Text("We're adding a paywall soon to unlock unlimited trips and premium features. Stay tuned!")
                    .font(DesignTokens.Typography.footnote)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .padding(.horizontal, DesignTokens.Spacing.md)
            }
        }
    }
    
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Notifications")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.md)
            
            CTCard(padding: DesignTokens.Spacing.md, elevation: .medium) {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Toggle("Enable Notifications", isOn: $viewModel.preferences.notificationSettings.enableNotifications)
                        .font(DesignTokens.Typography.body)
                    
                    Divider()
                    
                    Toggle("Sound", isOn: $viewModel.preferences.notificationSettings.soundEnabled)
                        .font(DesignTokens.Typography.body)
                        .disabled(!viewModel.preferences.notificationSettings.enableNotifications)
                    
                    Toggle("Vibration", isOn: $viewModel.preferences.notificationSettings.vibrationEnabled)
                        .font(DesignTokens.Typography.body)
                        .disabled(!viewModel.preferences.notificationSettings.enableNotifications)
                    
                    if #available(iOS 16.1, *) {
                        Divider()
                        
                        Toggle("Dynamic Island Updates", isOn: Binding(
                            get: { viewModel.preferences.notificationSettings.dynamicIslandUpdatesEnabled },
                            set: { newValue in
                                Task {
                                    await viewModel.handleDynamicIslandToggle(newValue)
                                    if !newValue {
                                        viewModel.preferences.notificationSettings.dynamicIslandUpdatesEnabled = false
                                    }
                                }
                            }
                        ))
                        .font(DesignTokens.Typography.body)
                        .disabled(!viewModel.preferences.notificationSettings.enableNotifications)
                    }
                    
                    Divider()
                    
                    Toggle("Personalized Daily Notifications", isOn: Binding(
                        get: { viewModel.preferences.notificationSettings.personalizedDailyNotificationsEnabled },
                        set: { newValue in
                            Task {
                                await viewModel.handlePersonalizedNotificationsToggle(newValue)
                                if !newValue {
                                    viewModel.preferences.notificationSettings.personalizedDailyNotificationsEnabled = false
                                }
                            }
                        }
                    ))
                    .font(DesignTokens.Typography.body)
                    .disabled(!viewModel.preferences.notificationSettings.enableNotifications)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            
            if viewModel.preferences.notificationSettings.personalizedDailyNotificationsEnabled {
                Text("Receive a personalized daily notification with your commute insights.")
                    .font(DesignTokens.Typography.footnote)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .padding(.horizontal, DesignTokens.Spacing.md)
            }
        }
    }
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Appearance")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.md)
            
            CTCard(padding: DesignTokens.Spacing.md, elevation: .medium) {
                Button {
                    showingThemePicker = true
                } label: {
                    HStack {
                        Image(systemName: themeManager.currentTheme.iconName)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        Text("Theme")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        Spacer()
                        Text(themeManager.currentTheme.displayName)
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            
            Text("Choose your preferred theme or follow system settings")
                .font(DesignTokens.Typography.footnote)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, DesignTokens.Spacing.md)
        }
    }
    
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Privacy")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.md)
            
            CTCard(padding: DesignTokens.Spacing.md, elevation: .medium) {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Toggle("Analytics", isOn: $viewModel.preferences.privacySettings.analyticsEnabled)
                        .font(DesignTokens.Typography.body)
                        .onChange(of: viewModel.preferences.privacySettings.analyticsEnabled) { _, newValue in
                            viewModel.analyticsService.setEnabled(newValue)
                        }
                    
                    Divider()
                    
                    Toggle("Data Sharing", isOn: $viewModel.preferences.privacySettings.dataSharingEnabled)
                        .font(DesignTokens.Typography.body)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            
            Text("Help improve CommuteTimely by sharing anonymous usage data")
                .font(DesignTokens.Typography.footnote)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, DesignTokens.Spacing.md)
        }
    }
    
    private var displaySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Display")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.md)
            
            CTCard(padding: DesignTokens.Spacing.md, elevation: .medium) {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Button {
                        showingTemperaturePicker = true
                    } label: {
                        HStack {
                            Text("Temperature")
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            Spacer()
                            Text(viewModel.preferences.displaySettings.temperatureUnit.symbol)
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                    }
                    
                    Divider()
                    
                    Button {
                        showingDistancePicker = true
                    } label: {
                        HStack {
                            Text("Distance")
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            Spacer()
                            Text(viewModel.preferences.displaySettings.distanceUnit.abbreviation)
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("About")
                .font(DesignTokens.Typography.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.md)
            
            CTCard(padding: DesignTokens.Spacing.md, elevation: .medium) {
                VStack(spacing: DesignTokens.Spacing.md) {
                    HStack {
                        Text("Version")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        Spacer()
                        Text(AppConfiguration.appVersion)
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
    }
    

    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Settings ViewModel

@MainActor
class SettingsViewModel: BaseViewModel {
    @Published var preferences: UserPreferences = UserPreferences()
    @Published var subscriptionStatus: SubscriptionStatus = SubscriptionStatus()
    @Published var showPermissionAlert = false
    
    let userPreferencesService: UserPreferencesServiceProtocol
    let subscriptionService: SubscriptionServiceProtocol
    let analyticsService: AnalyticsServiceProtocol
    let personalizedNotificationScheduler: PersonalizedNotificationSchedulerProtocol
    let commuteActivityManager: CommuteActivityManagerProtocol
    let authManager: AuthSessionController
    
    init(
        userPreferencesService: UserPreferencesServiceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        analyticsService: AnalyticsServiceProtocol,
        personalizedNotificationScheduler: PersonalizedNotificationSchedulerProtocol,
        commuteActivityManager: CommuteActivityManagerProtocol,
        authManager: AuthSessionController
    ) {
        self.userPreferencesService = userPreferencesService
        self.subscriptionService = subscriptionService
        self.analyticsService = analyticsService
        self.personalizedNotificationScheduler = personalizedNotificationScheduler
        self.commuteActivityManager = commuteActivityManager
        self.authManager = authManager
        super.init()
        
        // Subscribe to preferences updates
        userPreferencesService.preferences
            .sink { [weak self] prefs in
                self?.preferences = prefs
            }
            .store(in: &cancellables)
        
        // Subscribe to subscription status updates
        subscriptionService.subscriptionStatus
            .sink { [weak self] status in
                self?.subscriptionStatus = status
                
                // Update preferences with new subscription status
                if var prefs = self?.preferences {
                    prefs.subscriptionStatus = status
                    self?.preferences = prefs
                    
                    Task {
                        try? await self?.userPreferencesService.updatePreferences(prefs)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    override func onAppear() {
        analyticsService.trackScreen("Settings")
        
        Task {
            preferences = await userPreferencesService.loadPreferences()
            
            // Refresh subscription status
            await subscriptionService.refreshSubscriptionStatus()
        }
    }
    
    func savePreferences() {
        Task {
            try? await userPreferencesService.updatePreferences(preferences)
        }
    }
    
    func restorePurchases() async {
        do {
            try await subscriptionService.restorePurchases()
            await subscriptionService.refreshSubscriptionStatus()
        } catch {
            print("[Settings] Failed to restore purchases: \(error)")
        }
    }
    
    func handleDynamicIslandToggle(_ enabled: Bool) async {
        if !enabled {
            // End all Live Activities when disabled
            await commuteActivityManager.endAllActivities()
            preferences.notificationSettings.dynamicIslandUpdatesEnabled = false
            try? await userPreferencesService.updatePreferences(preferences)
        } else {
            // Check if activities are enabled
            let areEnabled = await commuteActivityManager.areActivitiesEnabled()
            if !areEnabled {
                showPermissionAlert = true
                preferences.notificationSettings.dynamicIslandUpdatesEnabled = false
                return
            }
            preferences.notificationSettings.dynamicIslandUpdatesEnabled = true
            try? await userPreferencesService.updatePreferences(preferences)
        }
    }
    
    func handlePersonalizedNotificationsToggle(_ enabled: Bool) async {
        if enabled {
            // Request permission first
            let hasPermission = await personalizedNotificationScheduler.requestPermissionIfNeeded()
            
            if !hasPermission {
                // Permission denied - show alert
                showPermissionAlert = true
                preferences.notificationSettings.personalizedDailyNotificationsEnabled = false
                return
            }
            
            // Get firstName from auth manager
            let firstName = authManager.currentUser?.firstName ?? "Friend"
            
            do {
                try await personalizedNotificationScheduler.scheduleDailyNotifications(firstName: firstName)
                preferences.notificationSettings.personalizedDailyNotificationsEnabled = true
                try? await userPreferencesService.updatePreferences(preferences)
            } catch {
                print("[Settings] Failed to schedule personalized notifications: \(error)")
                preferences.notificationSettings.personalizedDailyNotificationsEnabled = false
            }
        } else {
            // Cancel all personalized notifications
            await personalizedNotificationScheduler.cancelAllPersonalizedNotifications()
            preferences.notificationSettings.personalizedDailyNotificationsEnabled = false
            try? await userPreferencesService.updatePreferences(preferences)
        }
    }
}

// MARK: - Picker Sheets

struct ThemePickerSheet: View {
    @Binding var selectedTheme: ThemeMode
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(ThemeMode.allCases, id: \.self) { mode in
                    Button {
                        selectedTheme = mode
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: mode.iconName)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            Text(mode.displayName)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            Spacer()
                            if selectedTheme == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(DesignTokens.Colors.primaryFallback())
                            }
                        }
                    }
                }
            }
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct TemperatureUnitPickerSheet: View {
    @Binding var selectedUnit: TemperatureUnit
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                    Button {
                        selectedUnit = unit
                        dismiss()
                    } label: {
                        HStack {
                            Text(unit.symbol)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            Spacer()
                            if selectedUnit == unit {
                                Image(systemName: "checkmark")
                                    .foregroundColor(DesignTokens.Colors.primaryFallback())
                            }
                        }
                    }
                }
            }
            .navigationTitle("Temperature")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct DistanceUnitPickerSheet: View {
    @Binding var selectedUnit: DistanceUnit
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(DistanceUnit.allCases, id: \.self) { unit in
                    Button {
                        selectedUnit = unit
                        dismiss()
                    } label: {
                        HStack {
                            Text(unit.abbreviation)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            Spacer()
                            if selectedUnit == unit {
                                Image(systemName: "checkmark")
                                    .foregroundColor(DesignTokens.Colors.primaryFallback())
                            }
                        }
                    }
                }
            }
            .navigationTitle("Distance")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
