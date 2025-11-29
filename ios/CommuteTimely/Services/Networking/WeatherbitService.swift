//
// WeatherbitService.swift
// CommuteTimely
//
// Service for weather data from Weatherbit.io
//

import Foundation

protocol WeatherServiceProtocol {
    func getCurrentWeather(at coordinate: Coordinate) async throws -> WeatherData
    func getHourlyForecast(at coordinate: Coordinate) async throws -> [HourlyWeather]
}

class WeatherbitService: WeatherServiceProtocol {
    private let networkService: NetworkServiceProtocol
    private let apiKey: String
    private let baseURL = "https://api.weatherbit.io/v2.0"
    
    init(networkService: NetworkServiceProtocol, apiKey: String) {
        self.networkService = networkService
        self.apiKey = apiKey
    }
    
    func getCurrentWeather(at coordinate: Coordinate) async throws -> WeatherData {
        let path = "/current"
        
        // Validate API key
        guard !apiKey.isEmpty else {
            throw WeatherError.invalidAPIKey
        }
        
        let queryItems = [
            URLQueryItem(name: "lat", value: "\(coordinate.latitude)"),
            URLQueryItem(name: "lon", value: "\(coordinate.longitude)"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "units", value: "M") // Metric
        ]
        
        let endpoint = Endpoint(
            baseURL: baseURL,
            path: path,
            method: .get,
            queryItems: queryItems
        )
        
        do {
            let response: WeatherbitCurrentResponse = try await networkService.request(endpoint)
            
            guard let data = response.data.first else {
                throw WeatherError.noDataAvailable
            }
            
            return WeatherData(
                temperature: data.temp,
                feelsLike: data.appTemp,
                conditions: mapWeatherCode(data.weather.code),
                precipitation: data.precip,
                precipitationProbability: Double(data.pop ?? 0),
                windSpeed: data.windSpd,
                windDirection: data.windDir,
                visibility: data.vis,
                humidity: data.rh,
                pressure: data.pres,
                uvIndex: Int(data.uv),
                cloudCoverage: data.clouds,
                timestamp: Date(),
                alerts: []
            )
        } catch {
            // Check if it's an API key error
            if let networkError = error as? NetworkError,
               case .unauthorized = networkError {
                throw WeatherError.invalidAPIKey
            }
            throw error
        }
    }
    
    func getHourlyForecast(at coordinate: Coordinate) async throws -> [HourlyWeather] {
        let path = "/forecast/hourly"
        
        // Validate API key
        guard !apiKey.isEmpty else {
            throw WeatherError.invalidAPIKey
        }
        
        let queryItems = [
            URLQueryItem(name: "lat", value: "\(coordinate.latitude)"),
            URLQueryItem(name: "lon", value: "\(coordinate.longitude)"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "hours", value: "48"), // Get 48 hours for better coverage
            URLQueryItem(name: "units", value: "M")
        ]
        
        let endpoint = Endpoint(
            baseURL: baseURL,
            path: path,
            method: .get,
            queryItems: queryItems
        )
        
        do {
            let response: WeatherbitForecastResponse = try await networkService.request(endpoint)
        
        // Create date formatter for Weatherbit timestamp format (e.g., "2024-01-15T14:00")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        
        return response.data.map { hour in
            // Try ISO8601 first, then custom format, then fallback to current date
            var timestamp = Date()
            if let isoDate = ISO8601DateFormatter().date(from: hour.timestampLocal) {
                timestamp = isoDate
            } else if let customDate = dateFormatter.date(from: hour.timestampLocal) {
                timestamp = customDate
            }
            
            return HourlyWeather(
                timestamp: timestamp,
                temperature: hour.temp,
                conditions: mapWeatherCode(hour.weather.code),
                precipitationProbability: Double(hour.pop),
                windSpeed: hour.windSpd
            )
        }
        } catch {
            // Check if it's an API key error
            if let networkError = error as? NetworkError,
               case .unauthorized = networkError {
                throw WeatherError.invalidAPIKey
            }
            throw error
        }
    }
    
    private func mapWeatherCode(_ code: Int) -> WeatherCondition {
        switch code {
        case 800: return .clear
        case 801...802: return .partlyCloudy
        case 803: return .cloudy
        case 804: return .overcast
        case 700...711: return .mist
        case 721...741: return .fog
        case 300...302: return .drizzle
        case 500...501: return .lightRain
        case 502...522: return .rain
        case 531...532: return .heavyRain
        case 600...601: return .lightSnow
        case 602: return .snow
        case 621...623: return .heavySnow
        case 610...612: return .sleet
        case 511: return .freezingRain
        case 200...233: return .thunderstorm
        default: return .unknown
        }
    }
}

// MARK: - Weatherbit DTOs

struct WeatherbitCurrentResponse: Codable {
    let data: [WeatherbitCurrentData]
}

struct WeatherbitCurrentData: Codable {
    let temp: Double
    let appTemp: Double
    let precip: Double
    let pop: Int?
    let windSpd: Double
    let windDir: Int
    let vis: Double
    let rh: Int
    let pres: Double
    let uv: Double
    let clouds: Int
    let weather: WeatherbitWeatherDescription
    
    enum CodingKeys: String, CodingKey {
        case temp
        case appTemp = "app_temp"
        case precip
        case pop
        case windSpd = "wind_spd"
        case windDir = "wind_dir"
        case vis
        case rh
        case pres
        case uv
        case clouds
        case weather
    }
}

struct WeatherbitForecastResponse: Codable {
    let data: [WeatherbitHourlyData]
}

struct WeatherbitHourlyData: Codable {
    let timestampLocal: String
    let temp: Double
    let pop: Int
    let windSpd: Double
    let weather: WeatherbitWeatherDescription
    
    enum CodingKeys: String, CodingKey {
        case timestampLocal = "timestamp_local"
        case temp
        case pop
        case windSpd = "wind_spd"
        case weather
    }
}

struct WeatherbitWeatherDescription: Codable {
    let code: Int
    let description: String
}

// MARK: - Errors

enum WeatherError: LocalizedError {
    case noDataAvailable
    case invalidAPIKey
    
    var errorDescription: String? {
        switch self {
        case .noDataAvailable:
            return "Weather data is not available"
        case .invalidAPIKey:
            return "Invalid Weatherbit API key"
        }
    }
}

// MARK: - Mock Service

class MockWeatherService: WeatherServiceProtocol {
    func getCurrentWeather(at coordinate: Coordinate) async throws -> WeatherData {
        try await Task.sleep(nanoseconds: 300_000_000)
        
        return WeatherData(
            temperature: 22.0,
            feelsLike: 21.0,
            conditions: .partlyCloudy,
            precipitation: 0.0,
            precipitationProbability: 20.0,
            windSpeed: 5.5,
            windDirection: 180,
            visibility: 10.0,
            humidity: 65,
            pressure: 1013.25,
            uvIndex: 5,
            cloudCoverage: 40,
            timestamp: Date(),
            alerts: []
        )
    }
    
    func getHourlyForecast(at coordinate: Coordinate) async throws -> [HourlyWeather] {
        try await Task.sleep(nanoseconds: 300_000_000)
        
        let hours = Array(0..<24)
        return hours.map { hour -> HourlyWeather in
            let timestamp = Date().addingTimeInterval(Double(hour) * 3600)
            let temperature = 20.0 + Double(hour % 12)
            let conditions: WeatherCondition = hour % 3 == 0 ? .cloudy : .partlyCloudy
            let precipitationProbability = Double(hour * 2)
            let windSpeed = 5.0 + Double(hour % 5)
            
            return HourlyWeather(
                timestamp: timestamp,
                temperature: temperature,
                conditions: conditions,
                precipitationProbability: precipitationProbability,
                windSpeed: windSpeed
            )
        }
    }
}

