//
// WeatherData.swift
// CommuteTimely
//
// Weather data models for weather conditions and forecasts
//

import Foundation

struct WeatherData: Codable, Equatable {
    let temperature: Double // Celsius
    let feelsLike: Double
    let conditions: WeatherCondition
    let precipitation: Double // mm
    let precipitationProbability: Double // 0-100
    let windSpeed: Double // m/s
    let windDirection: Int // degrees
    let visibility: Double // km
    let humidity: Int // percentage
    let pressure: Double // mb
    let uvIndex: Int
    let cloudCoverage: Int // percentage
    let timestamp: Date
    let alerts: [WeatherAlert]
    
    var temperatureInFahrenheit: Double {
        (temperature * 9/5) + 32
    }
    
    var windSpeedInMPH: Double {
        windSpeed * 2.23694
    }
    
    var weatherScore: Double {
        // Score from 0 (terrible) to 100 (perfect)
        var score = 100.0
        
        // Penalize for precipitation
        score -= precipitationProbability * 0.3
        
        // Penalize for extreme temperatures
        if temperature < 0 || temperature > 35 {
            score -= 20
        }
        
        // Penalize for low visibility
        if visibility < 5 {
            score -= 15
        }
        
        // Penalize for high wind
        if windSpeed > 10 {
            score -= 10
        }
        
        // Penalize for severe weather
        if conditions == .thunderstorm || conditions == .snow || conditions == .freezingRain {
            score -= 25
        }
        
        return max(0, min(100, score))
    }
}

enum WeatherCondition: String, Codable {
    case clear
    case partlyCloudy
    case cloudy
    case overcast
    case mist
    case fog
    case lightRain
    case rain
    case heavyRain
    case drizzle
    case lightSnow
    case snow
    case heavySnow
    case sleet
    case freezingRain
    case thunderstorm
    case hail
    case unknown
    
    var icon: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy, .overcast: return "cloud.fill"
        case .mist, .fog: return "cloud.fog.fill"
        case .lightRain, .drizzle: return "cloud.drizzle.fill"
        case .rain: return "cloud.rain.fill"
        case .heavyRain: return "cloud.heavyrain.fill"
        case .lightSnow: return "cloud.snow.fill"
        case .snow, .heavySnow: return "cloud.snow.fill"
        case .sleet: return "cloud.sleet.fill"
        case .freezingRain: return "cloud.hail.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .hail: return "cloud.hail.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    var description: String {
        switch self {
        case .clear: return "Clear"
        case .partlyCloudy: return "Partly Cloudy"
        case .cloudy: return "Cloudy"
        case .overcast: return "Overcast"
        case .mist: return "Misty"
        case .fog: return "Foggy"
        case .lightRain: return "Light Rain"
        case .rain: return "Rain"
        case .heavyRain: return "Heavy Rain"
        case .drizzle: return "Drizzle"
        case .lightSnow: return "Light Snow"
        case .snow: return "Snow"
        case .heavySnow: return "Heavy Snow"
        case .sleet: return "Sleet"
        case .freezingRain: return "Freezing Rain"
        case .thunderstorm: return "Thunderstorm"
        case .hail: return "Hail"
        case .unknown: return "Unknown"
        }
    }
    
    var impactOnTravel: TravelImpact {
        switch self {
        case .clear, .partlyCloudy, .cloudy, .overcast:
            return .none
        case .mist, .lightRain, .drizzle:
            return .minor
        case .rain, .fog, .lightSnow:
            return .moderate
        case .heavyRain, .snow, .sleet:
            return .major
        case .heavySnow, .freezingRain, .thunderstorm, .hail:
            return .severe
        case .unknown:
            return .none
        }
    }
}

enum TravelImpact: String, Codable {
    case none
    case minor
    case moderate
    case major
    case severe
    
    var delayMultiplier: Double {
        switch self {
        case .none: return 1.0
        case .minor: return 1.1
        case .moderate: return 1.2
        case .major: return 1.35
        case .severe: return 1.5
        }
    }
}

struct WeatherAlert: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let description: String
    let severity: AlertSeverity
    let startTime: Date
    let endTime: Date
    let regions: [String]
}

enum AlertSeverity: String, Codable {
    case advisory
    case watch
    case warning
    case emergency
    
    var color: String {
        switch self {
        case .advisory: return "yellow"
        case .watch: return "orange"
        case .warning: return "red"
        case .emergency: return "purple"
        }
    }
}

// MARK: - Weather Forecast

struct WeatherForecast: Codable {
    let hourly: [HourlyWeather]
    let daily: [DailyWeather]
}

struct HourlyWeather: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let temperature: Double
    let conditions: WeatherCondition
    let precipitationProbability: Double
    let windSpeed: Double
    
    init(
        id: UUID = UUID(),
        timestamp: Date,
        temperature: Double,
        conditions: WeatherCondition,
        precipitationProbability: Double,
        windSpeed: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.temperature = temperature
        self.conditions = conditions
        self.precipitationProbability = precipitationProbability
        self.windSpeed = windSpeed
    }
}

struct DailyWeather: Codable, Identifiable {
    let id: UUID
    let date: Date
    let temperatureHigh: Double
    let temperatureLow: Double
    let conditions: WeatherCondition
    let precipitationProbability: Double
    
    init(
        id: UUID = UUID(),
        date: Date,
        temperatureHigh: Double,
        temperatureLow: Double,
        conditions: WeatherCondition,
        precipitationProbability: Double
    ) {
        self.id = id
        self.date = date
        self.temperatureHigh = temperatureHigh
        self.temperatureLow = temperatureLow
        self.conditions = conditions
        self.precipitationProbability = precipitationProbability
    }
}

