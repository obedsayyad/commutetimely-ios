//
// DIContainer.swift
// CommuteTimely
//
// Dependency Injection container for centralized service management
//

import Foundation
import OSLog
import Supabase

protocol ServiceContainer {
    var locationService: LocationServiceProtocol { get }
    var networkService: NetworkServiceProtocol { get }
    var mapboxService: MapboxServiceProtocol { get }
    var weatherService: WeatherServiceProtocol { get }
    var searchService: SearchServiceProtocol { get }
    var trafficWeatherService: TrafficWeatherMergeServiceProtocol { get }
    var analyticsService: AnalyticsServiceProtocol { get }
    var subscriptionService: SubscriptionServiceProtocol { get }
    var mlPredictionService: MLPredictionServiceProtocol { get }
    var predictionEngine: PredictionEngineProtocol { get }
    var notificationService: NotificationServiceProtocol { get }
    var leaveTimeNotificationScheduler: LeaveTimeNotificationSchedulerProtocol { get }
    var leaveTimeScheduler: LeaveTimeSchedulerProtocol { get }
    var tripStorageService: TripStorageServiceProtocol { get }
    var userPreferencesService: UserPreferencesServiceProtocol { get }
    var authManager: AuthSessionController { get }
    var cloudSyncService: CloudSyncServiceProtocol { get }
    var themeManager: ThemeManager { get }
    var personalizedNotificationScheduler: PersonalizedNotificationSchedulerProtocol { get }
    var commuteActivityManager: CommuteActivityManagerProtocol { get }
    
    // MARK: - Supabase Services
    
    var supabaseAuthService: SupabaseAuthServiceProtocol { get }
    var userProfileService: UserProfileServiceProtocol { get }
    var destinationService: DestinationServiceProtocol { get }
    var tripPlanService: TripPlanServiceProtocol { get }
    var notificationSettingsService: NotificationSettingsServiceProtocol { get }
    var predictionLogService: PredictionLogServiceProtocol { get }
}

class DIContainer: ServiceContainer {
    
    // MARK: - Singleton
    
    static let shared = DIContainer()
    
    // MARK: - External Clients
    
    /// Supabase client for authentication and data services
    private(set) var supabaseClient: SupabaseClient?
    
    // MARK: - Logging
    
    private static let logger = Logger(subsystem: "com.commutetimely.di", category: "DIContainer")
    
    // MARK: - Configuration
    
    /// Configure the Supabase client for use throughout the app
    /// This should be called once during app initialization
    func configureSupabase(client: SupabaseClient) {
        if self.supabaseClient != nil {
            Self.logger.warning("⚠️ Supabase client already configured - skipping reconfiguration")
            #if DEBUG
            print("[DIContainer] ⚠️ Supabase client already configured - skipping")
            #endif
            return
        }
        
        self.supabaseClient = client
        Self.logger.info("✅ Supabase client configured successfully")
        
        #if DEBUG
        print("[DIContainer] ✅ Supabase client configured")
        print("[DIContainer] URL: \(AppSecrets.supabaseURL)")
        print("[DIContainer] Key: \(String(AppSecrets.supabaseAnonKey.prefix(20)))...")
        print("[DIContainer] Client instance: \(ObjectIdentifier(client))")
        #endif
    }
    
    /// Returns true if Supabase is properly configured
    var isSupabaseConfigured: Bool {
        return supabaseClient != nil
    }
    
    // MARK: - Services
    
    lazy var locationService: LocationServiceProtocol = {
        LocationService()
    }()
    
    lazy var networkService: NetworkServiceProtocol = {
        NetworkService(authTokenProvider: { [weak self] in
            guard let self else { return nil }
            return try? await self.authManager.idToken()
        })
    }()
    
    lazy var mapboxService: MapboxServiceProtocol = {
        guard let accessToken = AppConfiguration.mapboxAccessToken else {
            Self.logger.warning("Mapbox access token is missing. Using mock service.")
            return MockMapboxService()
        }
        return MapboxService(
            networkService: networkService,
            accessToken: accessToken
        )
    }()
    
    lazy var weatherService: WeatherServiceProtocol = {
        guard let apiKey = AppConfiguration.weatherbitAPIKey else {
            Self.logger.warning("Weatherbit API key is missing. Using mock service.")
            return MockWeatherService()
        }
        return WeatherbitService(
            networkService: networkService,
            apiKey: apiKey
        )
    }()
    
    lazy var appleMapsSearchService: AppleMapsSearchServiceProtocol = {
        AppleMapsSearchService()
    }()
    
    lazy var searchService: SearchServiceProtocol = {
        SearchService(
            appleMapsSearchService: appleMapsSearchService,
            mapboxService: mapboxService,
            tripStorageService: tripStorageService
        )
    }()
    
    lazy var trafficWeatherService: TrafficWeatherMergeServiceProtocol = {
        TrafficWeatherMergeService(
            mapboxService: mapboxService,
            weatherService: weatherService
        )
    }()
    
    lazy var analyticsService: AnalyticsServiceProtocol = {
        var adapters: [AnalyticsAdapter] = []
        
        if let mixpanelToken = AppConfiguration.mixpanelToken {
            adapters.append(MixpanelAnalyticsAdapter(token: mixpanelToken))
        } else {
            Self.logger.info("Mixpanel token is missing. Analytics will run without Mixpanel adapter.")
        }
        
        // If no adapters, return a mock service (no-op)
        if adapters.isEmpty {
            return MockAnalyticsService()
        }
        
        return CompositeAnalyticsService(adapters: adapters)
    }()
    
    lazy var subscriptionService: SubscriptionServiceProtocol = {
        SubscriptionService(authManager: authManager)
    }()
    
    lazy var mlPredictionService: MLPredictionServiceProtocol = {
        // Use a default localhost URL if not configured, or fall back to mock
        let serverURL = AppConfiguration.predictionServerURL ?? "http://localhost:5000"
        Self.logger.info("ML Prediction Service using server URL: \(serverURL)")
        return MLPredictionService(
            networkService: networkService,
            serverURL: serverURL
        )
    }()
    
    lazy var predictionEngine: PredictionEngineProtocol = {
        PredictionEngine(
            trafficWeatherService: trafficWeatherService,
            mlService: mlPredictionService,
            userPreferencesService: userPreferencesService
        )
    }()
    
    lazy var notificationService: NotificationServiceProtocol = {
        NotificationService(
            mlPredictionService: mlPredictionService,
            tripStorageService: tripStorageService
        )
    }()
    
    lazy var leaveTimeNotificationScheduler: LeaveTimeNotificationSchedulerProtocol = {
        LeaveTimeNotificationScheduler()
    }()
    
    lazy var leaveTimeScheduler: LeaveTimeSchedulerProtocol = {
        LeaveTimeScheduler(
            predictionEngine: predictionEngine,
            notificationService: notificationService,
            leaveTimeNotificationScheduler: leaveTimeNotificationScheduler,
            commuteActivityManager: commuteActivityManager,
            userPreferencesService: userPreferencesService,
            tripStorageService: tripStorageService,
            locationService: locationService,
            authManager: authManager
        )
    }()
    
    lazy var tripStorageService: TripStorageServiceProtocol = {
        TripStorageService()
    }()
    
    lazy var userPreferencesService: UserPreferencesServiceProtocol = {
        UserPreferencesService()
    }()
    
    lazy var authManager: AuthSessionController = {
        let authService = SupabaseAuthService(client: supabaseClient ?? createFallbackClient())
        let controller = SupabaseAuthController(authService: authService)
        
        // Restore session on initialization
        Task { @MainActor in
            await controller.restoreSession()
        }
        
        return controller
    }()
    
    private func createFallbackClient() -> SupabaseClient {
        // Fallback client if Supabase wasn't configured yet
        // This should not happen in normal flow, but provides safety
        Self.logger.warning("⚠️ Creating fallback Supabase client - configureSupabase() was not called")
        
        #if DEBUG
        print("[DIContainer] ⚠️ Creating fallback Supabase client")
        print("[DIContainer] This indicates configureSupabase() was not called before accessing services")
        #endif
        
        let fallbackClient = SupabaseClient(
            supabaseURL: URL(string: AppSecrets.supabaseURL)!,
            supabaseKey: AppSecrets.supabaseAnonKey
        )
        
        // Store it so subsequent accesses use the same client
        self.supabaseClient = fallbackClient
        
        return fallbackClient
    }
    
    lazy var cloudSyncService: CloudSyncServiceProtocol = {
        // Use a default localhost URL if not configured, or fall back to mock
        let baseURL = AppConfiguration.authServerURL ?? "http://localhost:5000"
        Self.logger.info("Cloud Sync Service using base URL: \(baseURL)")
        return CloudSyncService(
            baseURL: baseURL,
            networkService: networkService,
            authTokenProvider: { [weak self] in
                guard let self = self else { return nil }
                return try? await self.authManager.idToken()
            }
        )
    }()
    
    lazy var themeManager: ThemeManager = {
        ThemeManager(analyticsService: analyticsService)
    }()
    
    lazy var personalizedNotificationScheduler: PersonalizedNotificationSchedulerProtocol = {
        PersonalizedNotificationScheduler(
            authManager: authManager,
            userPreferencesService: userPreferencesService,
            notificationService: notificationService
        )
    }()
    
    lazy var commuteActivityManager: CommuteActivityManagerProtocol = {
        CommuteActivityManager()
    }()
    
    // MARK: - Supabase Services
    
    lazy var supabaseAuthService: SupabaseAuthServiceProtocol = {
        guard let client = supabaseClient else {
            Self.logger.warning("⚠️ Supabase client not configured, using no-op auth service")
            #if DEBUG
            print("[DIContainer] ⚠️ supabaseAuthService: Using NoopSupabaseAuthService (no client)")
            #endif
            return NoopSupabaseAuthService()
        }
        #if DEBUG
        print("[DIContainer] ✅ supabaseAuthService: Using real SupabaseAuthService")
        print("[DIContainer]    Client instance: \(ObjectIdentifier(client))")
        #endif
        return SupabaseAuthService(client: client)
    }()
    
    @MainActor
    lazy var userProfileService: UserProfileServiceProtocol = {
        guard let client = supabaseClient else {
            Self.logger.warning("⚠️ Supabase client not configured, using no-op user profile service")
            #if DEBUG
            print("[DIContainer] ⚠️ userProfileService: Using NoopUserProfileService")
            #endif
            return NoopUserProfileService()
        }
        #if DEBUG
        print("[DIContainer] ✅ userProfileService: Using real UserProfileService")
        #endif
        return UserProfileService(client: client)
    }()
    
    @MainActor
    lazy var destinationService: DestinationServiceProtocol = {
        guard let client = supabaseClient else {
            Self.logger.warning("⚠️ Supabase client not configured, using no-op destination service")
            #if DEBUG
            print("[DIContainer] ⚠️ destinationService: Using NoopDestinationService")
            #endif
            return NoopDestinationService()
        }
        #if DEBUG
        print("[DIContainer] ✅ destinationService: Using real DestinationService")
        #endif
        return DestinationService(client: client)
    }()
    
    @MainActor
    lazy var tripPlanService: TripPlanServiceProtocol = {
        guard let client = supabaseClient else {
            Self.logger.warning("⚠️ Supabase client not configured, using no-op trip plan service")
            #if DEBUG
            print("[DIContainer] ⚠️ tripPlanService: Using NoopTripPlanService")
            #endif
            return NoopTripPlanService()
        }
        #if DEBUG
        print("[DIContainer] ✅ tripPlanService: Using real TripPlanService")
        #endif
        return TripPlanService(client: client)
    }()
    
    @MainActor
    lazy var notificationSettingsService: NotificationSettingsServiceProtocol = {
        guard let client = supabaseClient else {
            Self.logger.warning("⚠️ Supabase client not configured, using no-op notification settings service")
            #if DEBUG
            print("[DIContainer] ⚠️ notificationSettingsService: Using NoopNotificationSettingsService")
            #endif
            return NoopNotificationSettingsService()
        }
        #if DEBUG
        print("[DIContainer] ✅ notificationSettingsService: Using real NotificationSettingsService")
        #endif
        return NotificationSettingsService(client: client)
    }()
    
    lazy var predictionLogService: PredictionLogServiceProtocol = {
        guard let client = supabaseClient else {
            Self.logger.warning("⚠️ Supabase client not configured, using no-op prediction log service")
            #if DEBUG
            print("[DIContainer] ⚠️ predictionLogService: Using NoopPredictionLogService")
            #endif
            return NoopPredictionLogService()
        }
        #if DEBUG
        print("[DIContainer] ✅ predictionLogService: Using real PredictionLogService")
        #endif
        return PredictionLogService(client: client)
    }()
    
    // MARK: - Init
    
    private init() {
        // Private to enforce singleton
    }
    
    // MARK: - Factory for ViewModels
    
    func makeTripPlannerViewModel() -> TripPlannerViewModel {
        TripPlannerViewModel(
            mapboxService: mapboxService,
            searchService: searchService,
            weatherService: weatherService,
            mlPredictionService: mlPredictionService,
            tripStorageService: tripStorageService,
            subscriptionService: subscriptionService,
            analyticsService: analyticsService,
            leaveTimeScheduler: leaveTimeScheduler,
            locationService: locationService
        )
    }
    
    func makeTripListViewModel() -> TripListViewModel {
        TripListViewModel(
            tripStorageService: tripStorageService,
            analyticsService: analyticsService
        )
    }
    
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            userPreferencesService: userPreferencesService,
            subscriptionService: subscriptionService,
            analyticsService: analyticsService,
            personalizedNotificationScheduler: personalizedNotificationScheduler,
            commuteActivityManager: commuteActivityManager,
            authManager: authManager
        )
    }
}

// MARK: - Mock Container for Testing

class MockServiceContainer: ServiceContainer {
    var locationService: LocationServiceProtocol = MockLocationService()
    var networkService: NetworkServiceProtocol = MockNetworkService()
    var mapboxService: MapboxServiceProtocol = MockMapboxService()
    var weatherService: WeatherServiceProtocol = MockWeatherService()
    lazy var appleMapsSearchService: AppleMapsSearchServiceProtocol = AppleMapsSearchService()
    lazy var searchService: SearchServiceProtocol = {
        SearchService(
            appleMapsSearchService: appleMapsSearchService,
            mapboxService: mapboxService,
            tripStorageService: tripStorageService
        )
    }()
    var trafficWeatherService: TrafficWeatherMergeServiceProtocol = MockTrafficWeatherMergeService()
    var analyticsService: AnalyticsServiceProtocol = MockAnalyticsService()
    var subscriptionService: SubscriptionServiceProtocol = MockSubscriptionService()
    var mlPredictionService: MLPredictionServiceProtocol = MockMLPredictionService()
    lazy var predictionEngine: PredictionEngineProtocol = {
        PredictionEngine(
            trafficWeatherService: trafficWeatherService,
            mlService: mlPredictionService,
            userPreferencesService: userPreferencesService
        )
    }()
    var notificationService: NotificationServiceProtocol = MockNotificationService()
    var leaveTimeNotificationScheduler: LeaveTimeNotificationSchedulerProtocol = MockLeaveTimeNotificationScheduler()
    var commuteActivityManager: CommuteActivityManagerProtocol = MockCommuteActivityManager()
    lazy var leaveTimeScheduler: LeaveTimeSchedulerProtocol = {
        LeaveTimeScheduler(
            predictionEngine: predictionEngine,
            notificationService: notificationService,
            leaveTimeNotificationScheduler: leaveTimeNotificationScheduler,
            commuteActivityManager: commuteActivityManager,
            userPreferencesService: userPreferencesService,
            tripStorageService: tripStorageService,
            locationService: locationService,
            authManager: authManager
        )
    }()
    var tripStorageService: TripStorageServiceProtocol = MockTripStorageService()
    var userPreferencesService: UserPreferencesServiceProtocol = MockUserPreferencesService()
    lazy var authManager: AuthSessionController = {
        SupabaseMockAuthController()
    }()
    var cloudSyncService: CloudSyncServiceProtocol = MockCloudSyncService()
    var themeManager: ThemeManager = ThemeManager()
    var personalizedNotificationScheduler: PersonalizedNotificationSchedulerProtocol = MockPersonalizedNotificationScheduler()
    
    // MARK: - Supabase Services (Mocks)
    
    lazy var supabaseAuthService: SupabaseAuthServiceProtocol = NoopSupabaseAuthService()
    
    @MainActor
    lazy var userProfileService: UserProfileServiceProtocol = NoopUserProfileService()
    
    @MainActor
    lazy var destinationService: DestinationServiceProtocol = NoopDestinationService()
    
    @MainActor
    lazy var tripPlanService: TripPlanServiceProtocol = NoopTripPlanService()
    
    @MainActor
    lazy var notificationSettingsService: NotificationSettingsServiceProtocol = NoopNotificationSettingsService()
    
    lazy var predictionLogService: PredictionLogServiceProtocol = NoopPredictionLogService()
}
