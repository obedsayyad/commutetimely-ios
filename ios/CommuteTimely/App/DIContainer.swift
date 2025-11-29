//
// DIContainer.swift
// CommuteTimely
//
// Dependency Injection container for centralized service management
//

import Foundation

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
}

class DIContainer: ServiceContainer {
    
    // MARK: - Singleton
    
    static let shared = DIContainer()
    
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
        MapboxService(
            networkService: networkService,
            accessToken: AppConfiguration.mapboxAccessToken
        )
    }()
    
    lazy var weatherService: WeatherServiceProtocol = {
        WeatherbitService(
            networkService: networkService,
            apiKey: AppConfiguration.weatherbitAPIKey
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
        CompositeAnalyticsService(adapters: [
            MixpanelAnalyticsAdapter(token: AppConfiguration.mixpanelToken)
        ])
    }()
    
    lazy var subscriptionService: SubscriptionServiceProtocol = {
        SubscriptionService(authManager: authManager)
    }()
    
    lazy var mlPredictionService: MLPredictionServiceProtocol = {
        MLPredictionService(
            networkService: networkService,
            serverURL: AppConfiguration.predictionServerURL
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
        if AppConfiguration.useClerkMock {
            if AppConfiguration.isDebug {
                print("[Auth] Using Clerk mock provider via COMMUTETIMELY_USE_CLERK_MOCK flag")
            }
            return ClerkMockProvider()
        }
        #if canImport(Clerk)
        return ClerkAuthController()
        #else
        if AppConfiguration.isDebug {
            print("[Auth] Clerk SDK is not available on this platform. Falling back to mock auth.")
        }
        return ClerkMockProvider()
        #endif
    }()
    
    lazy var cloudSyncService: CloudSyncServiceProtocol = {
        CloudSyncService(
            baseURL: AppConfiguration.authServerURL,
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
            leaveTimeScheduler: leaveTimeScheduler
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
    lazy var authManager: AuthSessionController = ClerkMockProvider()
    var cloudSyncService: CloudSyncServiceProtocol = MockCloudSyncService()
    var themeManager: ThemeManager = ThemeManager()
    var personalizedNotificationScheduler: PersonalizedNotificationSchedulerProtocol = MockPersonalizedNotificationScheduler()
}
