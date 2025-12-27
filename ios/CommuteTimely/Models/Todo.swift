//
// Todo.swift
// CommuteTimely
//
// Simple Todo model for testing Supabase connectivity
//

import Foundation

/// A simple Todo item for testing Supabase database connectivity.
/// This model maps to the `todos` table in Supabase.
struct Todo: Identifiable, Codable, Equatable {
    var id: Int
    var title: String
    var isComplete: Bool?
    var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isComplete = "is_complete"
        case createdAt = "created_at"
    }
    
    init(id: Int, title: String, isComplete: Bool? = nil, createdAt: Date? = nil) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
        self.createdAt = createdAt
    }
}

