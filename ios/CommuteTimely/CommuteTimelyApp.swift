//
//  CommuteTimelyApp.swift
//  CommuteTimely
//
//  Production-ready app entry point with coordinator-based navigation
//

import SwiftUI
import Combine
import Supabase
import RevenueCat
import OSLog

@main
struct CommuteTimelyApp: App {
    @StateObject private var coordinator: AppCoordinator
    @StateObject private var themeManager: ThemeManager
    private let services: ServiceContainer
    private let supabaseClient: SupabaseClient
    private static let logger = Logger(subsystem: "com.commutetimely.app", category: "App")
    
    init() {
        // Log startup
        Self.logger.info("=== CommuteTimely Starting ===")
        #if DEBUG
        print("[App] === CommuteTimely Starting ===")
        print("[App] Supabase URL: \(AppSecrets.supabaseURL)")
        print("[App] Supabase Key prefix: \(String(AppSecrets.supabaseAnonKey.prefix(20)))...")
        
        // Validate Supabase key format
        if !AppSecrets.isSupabaseKeyValid {
            print("[App] ⚠️ WARNING: Supabase anon key appears invalid!")
            print("[App] ⚠️ Key should start with 'eyJ' and be a valid JWT")
            print("[App] ⚠️ Get the correct key from: Supabase Dashboard → Project Settings → API → anon key")
        } else {
            print("[App] ✅ Supabase key format validated")
        }
        #endif
        
        // Validate Supabase configuration
        guard let supabaseURL = URL(string: AppSecrets.supabaseURL) else {
            fatalError("Invalid Supabase URL: \(AppSecrets.supabaseURL)")
        }
        
        // Initialize Supabase client
        let client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: AppSecrets.supabaseAnonKey,
            options: .init(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )

        self.supabaseClient = client
        
        // Initialize services with Supabase
        let serviceContainer = DIContainer.shared
        serviceContainer.configureSupabase(client: client)
        self.services = serviceContainer
        
        // Configure RevenueCat
        Purchases.configure(withAPIKey: AppSecrets.revenueCatPublicAPIKey)
        
        // Initialize coordinator with services
        _coordinator = StateObject(wrappedValue: AppCoordinator(services: serviceContainer))
        
        // Initialize theme manager
        _themeManager = StateObject(wrappedValue: serviceContainer.themeManager)
        
        // Configure subscription service
        serviceContainer.subscriptionService.configure()
        
        // Log configuration status
        AppConfiguration.logConfigurationStatus()
        
        Self.logger.info("Supabase client configured successfully")
        
        #if DEBUG
        print("[App] ✅ Supabase client initialized")
        print("[App] ✅ RevenueCat configured")
        print("[App] ✅ Services initialized")
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
                .environmentObject(themeManager)
                .applyTheme(themeManager)
                .onAppear {
                    setupBackgroundTasks()
                }
                .onOpenURL { url in
                    // Handle deep links for Supabase auth callbacks (magic link, OAuth)
                    Self.logger.info("Received deep link URL: \(url.absoluteString)")
                    #if DEBUG
                    print("[App] 🔗 Received deep link: \(url.absoluteString)")
                    #endif
                    
                    Task {
                        do {
                            // Let Supabase handle the auth callback
                            try await supabaseClient.auth.session(from: url)
                            Self.logger.info("✅ Auth callback handled successfully")
                            #if DEBUG
                            print("[App] ✅ Auth callback handled successfully")
                            #endif
                            
                            // Refresh auth state after successful callback
                            if let controller = DIContainer.shared.authManager as? SupabaseAuthController {
                                await controller.refreshUser()
                            }
                        } catch {
                            Self.logger.error("❌ Failed to handle auth URL: \(error.localizedDescription)")
                            #if DEBUG
                            print("[App] ❌ Failed to handle auth URL: \(error.localizedDescription)")
                            #endif
                        }
                    }
                }
                .task {
                    // Test Supabase connectivity on launch
                    await testSupabaseConnectivity()
                    
                    // Perform initial background scheduling work
                    await services.leaveTimeScheduler.handleSignificantLocationChange()
                    // Update personalized notification schedule if needed
                    await services.personalizedNotificationScheduler.updateScheduleIfNeeded()
                }
        }
    }
    
    /// Tests Supabase connectivity on app launch and logs the results
    private func testSupabaseConnectivity() async {
        Self.logger.info("Testing Supabase connectivity...")
        #if DEBUG
        print("[App] Testing Supabase connectivity...")
        #endif
        
        // Test 1: Check if we can reach Supabase
        do {
            let session = try await supabaseClient.auth.session
            Self.logger.info("✅ Supabase connected - Session found for user: \(session.user.id)")
            #if DEBUG
            print("[App] ✅ Supabase connected - Active session for user: \(session.user.id)")
            #endif
        } catch {
            // No session is expected if user isn't signed in
            Self.logger.info("ℹ️ No active session (user not signed in)")
            #if DEBUG
            print("[App] ℹ️ No active session - user not signed in")
            #endif
        }
        
        // Test 2: Try to query the todos table (if it exists)
        #if DEBUG
        do {
            let todos: [Todo] = try await supabaseClient
                .from("todos")
                .select()
                .limit(1)
                .execute()
                .value
            print("[App] ✅ Todos table query successful - \(todos.count) items")
        } catch {
            let errorMessage = error.localizedDescription
            print("[App] ⚠️ Todos table query failed: \(errorMessage)")
            
            if errorMessage.contains("does not exist") {
                print("[App] 💡 Hint: Create a 'todos' table in Supabase Dashboard for testing")
            } else if errorMessage.contains("RLS") || errorMessage.contains("policy") {
                print("[App] 💡 Hint: Check RLS policies on the todos table")
            }
        }
        #endif
    }
    
    
    private func setupBackgroundTasks() {
        // Register background tasks for prediction updates
        services.notificationService.registerBackgroundTasks()
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    private let authManager = DIContainer.shared.authManager
    private let personalizedNotificationScheduler = DIContainer.shared.personalizedNotificationScheduler
    
    var body: some View {
        Group {
            switch coordinator.currentRoute {
            case .onboarding:
                OnboardingCoordinatorView()
            case .main:
                MainTabView()
            default:
                MainTabView()
            }
        }
        .task {
            // Observe auth state changes
            for await state in authManager.authStatePublisher.values {
                await handleAuthStateChange(state)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accountDeleted)) { _ in
            // Handle account deletion - reset app state
            URLCache.shared.removeAllCachedResponses()
            
            // Navigate to onboarding/login
            coordinator.resetOnboarding()
        }
    }
    
    private func handleAuthStateChange(_ state: AuthSessionState) async {
        switch state {
        case .signedOut:
            // Log out RevenueCat
            do {
                let _ = try await Purchases.shared.logOut()
                print("[App] RevenueCat logged out")
            } catch {
                print("[App] Failed to log out RevenueCat: \(error.localizedDescription)")
            }
            
            // Cancel all personalized notifications on sign out
            await personalizedNotificationScheduler.cancelAllPersonalizedNotifications()
            
            // Update preferences to disable personalized notifications
            let preferencesService = DIContainer.shared.userPreferencesService
            var preferences = await preferencesService.loadPreferences()
            preferences.notificationSettings.personalizedDailyNotificationsEnabled = false
            try? await preferencesService.updatePreferences(preferences)
            
        case .signedIn(let user):
            // Log in RevenueCat with Supabase user ID
            do {
                let (_, _) = try await Purchases.shared.logIn(user.id)
                print("[App] RevenueCat logged in with user ID: \(user.id)")
            } catch {
                print("[App] Failed to log in RevenueCat: \(error.localizedDescription)")
            }
            
            // Ensure user profile exists in Supabase
            let userProfileService = DIContainer.shared.userProfileService
            do {
                _ = try await userProfileService.fetchCurrentUserProfile()
            } catch {
                // Profile doesn't exist, create it
                let profile = UserProfile(
                    id: UUID(),
                    userId: UUID(uuidString: user.id) ?? UUID(),
                    name: user.displayName,
                    email: user.email,
                    avatarURL: user.imageURL,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                _ = try? await userProfileService.upsertProfile(profile)
            }
            
            // On sign in, check if personalized notifications are enabled and reschedule
            let preferencesService = DIContainer.shared.userPreferencesService
            let preferences = await preferencesService.loadPreferences()
            
            if preferences.notificationSettings.personalizedDailyNotificationsEnabled {
                // Reschedule with new user's firstName
                let firstName = user.firstName ?? "Friend"
                do {
                    try await personalizedNotificationScheduler.scheduleDailyNotifications(firstName: firstName)
                } catch {
                    print("[App] Failed to reschedule personalized notifications after sign in: \(error)")
                }
            }
        }
    }
}
