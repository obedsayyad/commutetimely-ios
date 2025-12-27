//
// TripPlanService.swift
// CommuteTimely
//
// Supabase trip_plans table service
//

import Foundation
import Supabase
import OSLog

@MainActor
final class TripPlanService: TripPlanServiceProtocol {
    private let client: SupabaseClient
    private var _cachedTodayPlans: [TripPlan] = []
    private static let logger = Logger(subsystem: "com.commutetimely.supabase", category: "TripPlanService")
    
    var cachedTodayPlans: [TripPlan] {
        _cachedTodayPlans
    }
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    func createTripPlan(request: NewTripPlanRequest) async throws -> TripPlan {
        do {
            // In Supabase v2, user() is an async throwing function
            let user = try await client.auth.user()
            let userId = user.id
            
            let plan = TripPlan(
                id: UUID(),
                userId: userId,
                destinationId: request.destinationId,
                plannedArrival: request.plannedArrival,
                predictedLeaveTime: request.predictedLeaveTime,
                routeSnapshotJSON: request.routeSnapshotJSON,
                weatherSummary: request.weatherSummary,
                modelVersion: request.modelVersion,
                status: "active",
                createdAt: Date(),
                updatedAt: Date()
            )
            
            let response: [TripPlan] = try await client
                .from("trip_plans")
                .insert(plan)
                .select()
                .execute()
                .value
            
            guard let savedPlan = response.first else {
                throw SupabaseError.invalidResponse
            }
            
            _cachedTodayPlans.append(savedPlan)
            return savedPlan
        } catch {
            Self.logger.error("Failed to create trip plan: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func getTripPlansForToday() async throws -> [TripPlan] {
        do {
            // In Supabase v2, user() is an async throwing function
            let user = try await client.auth.user()
            let userId = user.id
            
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let response: [TripPlan] = try await client
                .from("trip_plans")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("planned_arrival", value: startOfDay.ISO8601Format())
                .lt("planned_arrival", value: endOfDay.ISO8601Format())
                .order("planned_arrival", ascending: true)
                .execute()
                .value
            
            _cachedTodayPlans = response
            return response
        } catch {
            Self.logger.error("Failed to get trip plans for today: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func getTripPlans(forDestination destinationId: UUID) async throws -> [TripPlan] {
        do {
            // In Supabase v2, user() is an async throwing function
            let user = try await client.auth.user()
            let userId = user.id
            
            let response: [TripPlan] = try await client
                .from("trip_plans")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("destination_id", value: destinationId.uuidString)
                .order("planned_arrival", ascending: false)
                .execute()
                .value
            
            return response
        } catch {
            Self.logger.error("Failed to get trip plans for destination: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func updateTripPlan(_ plan: TripPlan) async throws -> TripPlan {
        do {
            var updatedPlan = plan
            updatedPlan.updatedAt = Date()
            
            let response: [TripPlan] = try await client
                .from("trip_plans")
                .update(updatedPlan)
                .eq("id", value: updatedPlan.id.uuidString)
                .select()
                .execute()
                .value
            
            guard let savedPlan = response.first else {
                throw SupabaseError.invalidResponse
            }
            
            if let index = _cachedTodayPlans.firstIndex(where: { $0.id == savedPlan.id }) {
                _cachedTodayPlans[index] = savedPlan
            }
            
            return savedPlan
        } catch {
            Self.logger.error("Failed to update trip plan: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
    
    func deleteOldTripPlans(before date: Date) async throws {
        do {
            // In Supabase v2, user() is an async throwing function
            let user = try await client.auth.user()
            let userId = user.id
            
            try await client
                .from("trip_plans")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .lt("created_at", value: date.ISO8601Format())
                .execute()
            
            _cachedTodayPlans.removeAll { ($0.createdAt ?? Date()) < date }
        } catch {
            Self.logger.error("Failed to delete old trip plans: \(error.localizedDescription)")
            throw SupabaseError.from(error: error, logger: Self.logger)
        }
    }
}
