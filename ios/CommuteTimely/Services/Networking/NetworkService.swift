//
// NetworkService.swift
// CommuteTimely
//
// Core networking service with retry logic and error handling
//

import Foundation

protocol NetworkServiceProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func request(_ endpoint: Endpoint) async throws -> Data
}

class NetworkService: NetworkServiceProtocol {
    private let session: URLSession
    private let maxRetries = 3
    private let baseBackoffDelay: TimeInterval = 1.0
    private let authTokenProvider: (() async throws -> String?)?
    
    init(
        session: URLSession = .shared,
        authTokenProvider: (() async throws -> String?)? = nil
    ) {
        self.session = session
        self.authTokenProvider = authTokenProvider
    }
    
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let data: Data = try await request(endpoint)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
    
    func request(_ endpoint: Endpoint) async throws -> Data {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                var request = try endpoint.urlRequest()
                
                if endpoint.requiresAuth {
                    guard let tokenProvider = authTokenProvider,
                          let token = try await tokenProvider()
                    else {
                        throw NetworkError.unauthorized
                    }
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 400:
                    throw NetworkError.badRequest
                case 401:
                    throw NetworkError.unauthorized
                case 403:
                    throw NetworkError.forbidden
                case 404:
                    throw NetworkError.notFound
                case 429:
                    throw NetworkError.rateLimited
                case 500...599:
                    throw NetworkError.serverError(httpResponse.statusCode)
                default:
                    throw NetworkError.unknownError(httpResponse.statusCode)
                }
            } catch let error as NetworkError {
                lastError = error
                
                // Don't retry on client errors
                if case .badRequest = error { throw error }
                if case .unauthorized = error { throw error }
                if case .forbidden = error { throw error }
                if case .notFound = error { throw error }
                
                // Retry on rate limit and server errors
                if attempt < maxRetries - 1 {
                    let backoffDelay = baseBackoffDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                }
            } catch {
                lastError = NetworkError.networkFailed(error)
                
                if attempt < maxRetries - 1 {
                    let backoffDelay = baseBackoffDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NetworkError.unknownError(0)
    }
}

// MARK: - Endpoint

struct Endpoint {
    let baseURL: String
    let path: String
    let method: HTTPMethod
    let headers: [String: String]
    let queryItems: [URLQueryItem]
    let body: Data?
    let requiresAuth: Bool
    
    init(
        baseURL: String,
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        requiresAuth: Bool = false
    ) {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
        self.requiresAuth = requiresAuth
    }
    
    func urlRequest() throws -> URLRequest {
        guard var components = URLComponents(string: baseURL + path) else {
            throw NetworkError.invalidURL
        }
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        // Default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return request
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Network Error

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(Int)
    case networkFailed(Error)
    case decodingFailed(Error)
    case unknownError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid"
        case .invalidResponse:
            return "Invalid response from server"
        case .badRequest:
            return "Bad request"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests. Please try again later"
        case .serverError(let code):
            return "Server error (\(code))"
        case .networkFailed(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .unknownError(let code):
            return "Unknown error (\(code))"
        }
    }
}

// MARK: - Mock Service

class MockNetworkService: NetworkServiceProtocol {
    var mockData: Data?
    var mockError: Error?
    
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        if let error = mockError {
            throw error
        }
        
        guard let data = mockData else {
            throw NetworkError.notFound
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
    
    func request(_ endpoint: Endpoint) async throws -> Data {
        if let error = mockError {
            throw error
        }
        
        return mockData ?? Data()
    }
}

