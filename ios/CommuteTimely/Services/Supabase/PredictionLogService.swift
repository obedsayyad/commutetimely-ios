//
// PredictionLogService.swift
// CommuteTimely
//
// Supabase prediction_logs table service (optional)
//

import Foundation
import Supabase
import OSLog

final class PredictionLogService: PredictionLogServiceProtocol {
    private let client: SupabaseClient
    private static let logger = Logger(subsystem: "com.commutetimely.supabase", category: "PredictionLogService")
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    func logPrediction(_ log: PredictionLog) async {
        do {
            // In Supabase v2, user() is an async throwing function
            let user = try await client.auth.user()
            let userId = user.id
            
            var logEntry = log
            logEntry.userId = userId
            
            try await client
                .from("prediction_logs")
                .insert(logEntry)
                .execute()
            
            Self.logger.debug("Prediction logged successfully")
        } catch {
            // Non-throwing: log errors but don't fail the prediction flow
            Self.logger.error("Failed to log prediction: \(error.localizedDescription)")
        }
    }
}
