//
// DestinationService.swift
// CommuteTimely
//
// Supabase destinations table service
//

import Foundation
import Supabase
import OSLog

@MainActor
final class DestinationService: DestinationServiceProtocol {
    private let client: SupabaseClient
    private var _cachedDestinations: [DestinationRecord] = []
    private static let logger = Logger(subsystem: "com.commutetimely.supabase", category: "DestinationService")
    
    var cachedDestinations: [DestinationRecord] {
        _cachedDestinations
    }
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    func listDestinations() async throws -> [DestinationRecord] {
        do {
            // In Supabase v2, user() is an async throwing function
            let user = try await client.auth.user()
            let userId = user.id
            
            let response: [DestinationRecord] = try await client
                .from("destinations")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            _cachedDestinations = response
            return response
        } catch {
            Self.logger.error("Failed to list destinations: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func addDestination(_ record: DestinationRecord) async throws -> DestinationRecord {
        do {
            // In Supabase v2, user() is an async throwing function
            let user = try await client.auth.user()
            let userId = user.id
            
            var newRecord = record
            newRecord.userId = userId
            newRecord.createdAt = Date()
            newRecord.updatedAt = Date()
            
            // Enforce home/work uniqueness
            if newRecord.isHome {
                try await clearOtherHomeDestinations(userId: userId)
            }
            if newRecord.isWork {
                try await clearOtherWorkDestinations(userId: userId)
            }
            
            let response: [DestinationRecord] = try await client
                .from("destinations")
                .insert(newRecord)
                .select()
                .execute()
                .value
            
            guard let savedRecord = response.first else {
                throw SupabaseError.invalidResponse
            }
            
            _cachedDestinations.append(savedRecord)
            return savedRecord
        } catch {
            Self.logger.error("Failed to add destination: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func updateDestination(_ record: DestinationRecord) async throws -> DestinationRecord {
        do {
            // In Supabase v2, user() is an async throwing function
            let user = try await client.auth.user()
            let userId = user.id
            
            var updatedRecord = record
            updatedRecord.userId = userId
            updatedRecord.updatedAt = Date()
            
            // Enforce home/work uniqueness
            if updatedRecord.isHome {
                try await clearOtherHomeDestinations(userId: userId, excluding: updatedRecord.id)
            }
            if updatedRecord.isWork {
                try await clearOtherWorkDestinations(userId: userId, excluding: updatedRecord.id)
            }
            
            let response: [DestinationRecord] = try await client
                .from("destinations")
                .update(updatedRecord)
                .eq("id", value: updatedRecord.id.uuidString)
                .select()
                .execute()
                .value
            
            guard let savedRecord = response.first else {
                throw SupabaseError.invalidResponse
            }
            
            if let index = _cachedDestinations.firstIndex(where: { $0.id == savedRecord.id }) {
                _cachedDestinations[index] = savedRecord
            }
            
            return savedRecord
        } catch {
            Self.logger.error("Failed to update destination: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func deleteDestination(id: UUID) async throws {
        do {
            try await client
                .from("destinations")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
            
            _cachedDestinations.removeAll { $0.id == id }
        } catch {
            Self.logger.error("Failed to delete destination: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func observeDestinations() -> AsyncStream<[DestinationRecord]> {
        AsyncStream { continuation in
            Task { @MainActor in
                do {
                    let destinations = try await listDestinations()
                    continuation.yield(destinations)
                } catch {
                    continuation.yield(_cachedDestinations)
                }
                
                // Note: Supabase Realtime would go here if enabled
                // For now, we just yield the cached list
                continuation.finish()
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func clearOtherHomeDestinations(userId: UUID, excluding excludeId: UUID? = nil) async throws {
        var query = try client
            .from("destinations")
            .update(["is_home": false])
            .eq("user_id", value: userId.uuidString)
            .eq("is_home", value: true)
        
        if let excludeId {
            query = query.neq("id", value: excludeId.uuidString)
        }
        
        try await query.execute()
    }
    
    private func clearOtherWorkDestinations(userId: UUID, excluding excludeId: UUID? = nil) async throws {
        var query = try client
            .from("destinations")
            .update(["is_work": false])
            .eq("user_id", value: userId.uuidString)
            .eq("is_work", value: true)
        
        if let excludeId {
            query = query.neq("id", value: excludeId.uuidString)
        }
        
        try await query.execute()
    }
}
