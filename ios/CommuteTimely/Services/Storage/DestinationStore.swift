//
//  DestinationStore.swift
//  CommuteTimely
//
//  Core Data backed repository for saved destinations and trips.
//

@preconcurrency import Foundation
import CoreData

protocol DestinationStoreProtocol {
    func fetchTrips() async throws -> [Trip]
    func saveTrip(_ trip: Trip) async throws
    func updateTrip(_ trip: Trip) async throws
    func deleteTrip(id: UUID) async throws
    func deleteAll() async throws
    func exportTrips() async throws -> Data
    func importTrips(from data: Data) async throws
}

final class CoreDataDestinationStore: DestinationStoreProtocol {
    private let container: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init(storeURL: URL? = nil, storeType: String = NSSQLiteStoreType) {
        let model = CoreDataDestinationStore.buildModel()
        container = NSPersistentContainer(name: "DestinationStore", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = storeType
        if let storeURL {
            description.url = storeURL
        }
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            assertionFailure("Failed to load destination store: \(loadError)")
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        backgroundContext = container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    func fetchTrips() async throws -> [Trip] {
        try await backgroundContext.perform {
            let request = NSFetchRequest<StoredTrip>(entityName: "StoredTrip")
            request.sortDescriptors = [
                NSSortDescriptor(key: "arrivalTime", ascending: true)
            ]
            let objects = try self.backgroundContext.fetch(request)
            return objects.compactMap { $0.makeTrip(decoder: self.decoder) }
        }
    }
    
    func saveTrip(_ trip: Trip) async throws {
        try await backgroundContext.perform {
            let object = StoredTrip(context: self.backgroundContext)
            object.update(with: trip, encoder: self.encoder)
            try self.backgroundContext.save()
        }
    }
    
    func updateTrip(_ trip: Trip) async throws {
        try await backgroundContext.perform {
            let request = StoredTrip.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", trip.id as CVarArg)
            guard let object = try self.backgroundContext.fetch(request).first else {
                throw TripStorageError.tripNotFound
            }
            object.update(with: trip, encoder: self.encoder)
            try self.backgroundContext.save()
        }
    }
    
    func deleteTrip(id: UUID) async throws {
        try await backgroundContext.perform {
            let request = StoredTrip.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let object = try self.backgroundContext.fetch(request).first {
                self.backgroundContext.delete(object)
                try self.backgroundContext.save()
            }
        }
    }
    
    func deleteAll() async throws {
        try await backgroundContext.perform {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "StoredTrip")
            let delete = NSBatchDeleteRequest(fetchRequest: request)
            try self.backgroundContext.execute(delete)
            try self.backgroundContext.save()
        }
    }
    
    func exportTrips() async throws -> Data {
        let trips = try await fetchTrips()
        return try encoder.encode(trips)
    }
    
    func importTrips(from data: Data) async throws {
        let trips = try decoder.decode([Trip].self, from: data)
        try await deleteAll()
        for trip in trips {
            try await saveTrip(trip)
        }
    }
    
    private static func buildModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "StoredTrip"
        entity.managedObjectClassName = NSStringFromClass(StoredTrip.self)
        
        func attribute(_ name: String, type: NSAttributeType, optional: Bool = false) -> NSAttributeDescription {
            let attribute = NSAttributeDescription()
            attribute.name = name
            attribute.attributeType = type
            attribute.isOptional = optional
            return attribute
        }
        
        entity.properties = [
            attribute("id", type: .UUIDAttributeType),
            attribute("arrivalTime", type: .dateAttributeType),
            attribute("bufferMinutes", type: .integer16AttributeType),
            attribute("isActive", type: .booleanAttributeType),
            attribute("createdAt", type: .dateAttributeType),
            attribute("updatedAt", type: .dateAttributeType),
            attribute("destinationLatitude", type: .doubleAttributeType),
            attribute("destinationLongitude", type: .doubleAttributeType),
            attribute("destinationAddress", type: .stringAttributeType),
            attribute("destinationPlaceName", type: .stringAttributeType, optional: true),
            attribute("destinationPlaceType", type: .stringAttributeType, optional: true),
            attribute("repeatDaysData", type: .binaryDataAttributeType, optional: true),
            attribute("notificationSettingsData", type: .binaryDataAttributeType, optional: true),
            attribute("customName", type: .stringAttributeType, optional: true),
            attribute("notes", type: .stringAttributeType, optional: true),
            attribute("transportMode", type: .stringAttributeType),
            attribute("tagsData", type: .binaryDataAttributeType, optional: true),
            attribute("lastRouteSnapshotData", type: .binaryDataAttributeType, optional: true),
            attribute("expectedWeatherSummary", type: .stringAttributeType, optional: true),
            attribute("arrivalBufferMinutes", type: .integer16AttributeType),
            attribute("lastKnownTrafficSummary", type: .stringAttributeType, optional: true)
        ]
        
        model.entities = [entity]
        return model
    }
}

// MARK: - Managed Object

@objc(StoredTrip)
final class StoredTrip: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var arrivalTime: Date
    @NSManaged var bufferMinutes: Int16
    @NSManaged var isActive: Bool
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var destinationLatitude: Double
    @NSManaged var destinationLongitude: Double
    @NSManaged var destinationAddress: String
    @NSManaged var destinationPlaceName: String?
    @NSManaged var destinationPlaceType: String?
    @NSManaged var repeatDaysData: Data?
    @NSManaged var notificationSettingsData: Data?
    @NSManaged var customName: String?
    @NSManaged var notes: String?
    @NSManaged var transportMode: String
    @NSManaged var tagsData: Data?
    @NSManaged var lastRouteSnapshotData: Data?
    @NSManaged var expectedWeatherSummary: String?
    @NSManaged var arrivalBufferMinutes: Int16
    @NSManaged var lastKnownTrafficSummary: String?
    
    @nonobjc class func fetchRequest() -> NSFetchRequest<StoredTrip> {
        NSFetchRequest<StoredTrip>(entityName: "StoredTrip")
    }
    
    // Helper methods for encoding/decoding @preconcurrency types
    // These types are marked @preconcurrency but their Codable conformance is MainActor-isolated
    // We use MainActor.run with a semaphore and Sendable wrapper to wait synchronously for the async operation
    
    // Sendable wrapper to safely hold result/error for concurrent access
    private final class ResultContainer<T>: @unchecked Sendable {
        var result: T?
        var error: Error?
        private let lock = NSLock()
        
        func setResult(_ value: T) {
            lock.lock()
            defer { lock.unlock() }
            result = value
        }
        
        func setError(_ value: Error) {
            lock.lock()
            defer { lock.unlock() }
            error = value
        }
        
        func getResult() -> T? {
            lock.lock()
            defer { lock.unlock() }
            return result
        }
        
        func getError() -> Error? {
            lock.lock()
            defer { lock.unlock() }
            return error
        }
    }
    
    private static func encodeTripNotificationSettings(_ value: TripNotificationSettings, encoder: JSONEncoder) throws -> Data {
        let semaphore = DispatchSemaphore(value: 0)
        let container = ResultContainer<Data>()
        
        Task { @MainActor in
            do {
                container.setResult(try encoder.encode(value))
            } catch {
                container.setError(error)
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = container.getError() {
            throw error
        }
        return container.getResult()!
    }
    
    private static func encodeRouteSnapshot(_ value: RouteSnapshot, encoder: JSONEncoder) throws -> Data {
        let semaphore = DispatchSemaphore(value: 0)
        let container = ResultContainer<Data>()
        
        Task { @MainActor in
            do {
                container.setResult(try encoder.encode(value))
            } catch {
                container.setError(error)
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = container.getError() {
            throw error
        }
        return container.getResult()!
    }
    
    private static func decodeTripNotificationSettings(from data: Data, decoder: JSONDecoder) throws -> TripNotificationSettings {
        let semaphore = DispatchSemaphore(value: 0)
        let container = ResultContainer<TripNotificationSettings>()
        
        Task { @MainActor in
            do {
                container.setResult(try decoder.decode(TripNotificationSettings.self, from: data))
            } catch {
                container.setError(error)
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = container.getError() {
            throw error
        }
        return container.getResult()!
    }
    
    private static func decodeRouteSnapshot(from data: Data, decoder: JSONDecoder) throws -> RouteSnapshot {
        let semaphore = DispatchSemaphore(value: 0)
        let container = ResultContainer<RouteSnapshot>()
        
        Task { @MainActor in
            do {
                container.setResult(try decoder.decode(RouteSnapshot.self, from: data))
            } catch {
                container.setError(error)
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = container.getError() {
            throw error
        }
        return container.getResult()!
    }
    
    func update(with trip: Trip, encoder: JSONEncoder) {
        id = trip.id
        arrivalTime = trip.arrivalTime
        bufferMinutes = Int16(trip.bufferMinutes)
        isActive = trip.isActive
        createdAt = trip.createdAt
        updatedAt = trip.updatedAt
        destinationLatitude = trip.destination.coordinate.latitude
        destinationLongitude = trip.destination.coordinate.longitude
        destinationAddress = trip.destination.address
        destinationPlaceName = trip.destination.placeName
        destinationPlaceType = trip.destination.placeType?.rawValue
        repeatDaysData = try? encoder.encode(Array(trip.repeatDays))
        // Encode @preconcurrency types in nonisolated context
        notificationSettingsData = try? StoredTrip.encodeTripNotificationSettings(trip.notificationSettings, encoder: encoder)
        customName = trip.customName
        notes = trip.notes
        transportMode = trip.transportMode.rawValue
        tagsData = try? encoder.encode(Array(trip.tags))
        // Encode @preconcurrency types in nonisolated context
        if let snapshot = trip.lastRouteSnapshot {
            lastRouteSnapshotData = try? StoredTrip.encodeRouteSnapshot(snapshot, encoder: encoder)
        }
        expectedWeatherSummary = trip.expectedWeatherSummary
        arrivalBufferMinutes = Int16(trip.arrivalBufferMinutes)
        lastKnownTrafficSummary = trip.cachedTrafficSummary
    }
    
    func makeTrip(decoder: JSONDecoder) -> Trip? {
        let destination = Location(
            coordinate: Coordinate(latitude: destinationLatitude, longitude: destinationLongitude),
            address: destinationAddress,
            placeName: destinationPlaceName,
            placeType: destinationPlaceType.flatMap { PlaceType(rawValue: $0) }
        )
        
        let repeatDaysArray = (try? decoder.decode([WeekDay].self, from: repeatDaysData ?? Data())) ?? []
        // Decode @preconcurrency types in nonisolated context
        let notificationSettings = (try? StoredTrip.decodeTripNotificationSettings(from: notificationSettingsData ?? Data(), decoder: decoder)) ?? TripNotificationSettings()
        let tagsArray = (try? decoder.decode([DestinationTag].self, from: tagsData ?? Data())) ?? []
        // Decode @preconcurrency types in nonisolated context
        let snapshot = try? StoredTrip.decodeRouteSnapshot(from: lastRouteSnapshotData ?? Data(), decoder: decoder)
        let transport = TransportMode(rawValue: transportMode) ?? .driving
        
        return Trip(
            id: id,
            destination: destination,
            arrivalTime: arrivalTime,
            bufferMinutes: Int(bufferMinutes),
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            repeatDays: Set(repeatDaysArray),
            notificationSettings: notificationSettings,
            customName: customName,
            notes: notes,
            transportMode: transport,
            tags: Set(tagsArray),
            lastRouteSnapshot: snapshot,
            expectedWeatherSummary: expectedWeatherSummary,
            arrivalBufferMinutes: Int(arrivalBufferMinutes)
        )
    }
}

// MARK: - In-memory Store (for previews/tests)

final class InMemoryDestinationStore: DestinationStoreProtocol {
    private var trips: [Trip] = []
    private let queue = DispatchQueue(label: "InMemoryDestinationStore")
    
    func fetchTrips() async throws -> [Trip] {
        queue.sync { trips }
    }
    
    func saveTrip(_ trip: Trip) async throws {
        queue.sync {
            trips.append(trip)
        }
    }
    
    func updateTrip(_ trip: Trip) async throws {
        queue.sync {
            if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[index] = trip
            }
        }
    }
    
    func deleteTrip(id: UUID) async throws {
        queue.sync {
            trips.removeAll { $0.id == id }
        }
    }
    
    func deleteAll() async throws {
        queue.sync { trips.removeAll() }
    }
    
    func exportTrips() async throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(trips)
    }
    
    func importTrips(from data: Data) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([Trip].self, from: data)
        queue.sync {
            trips = decoded
        }
    }
}

