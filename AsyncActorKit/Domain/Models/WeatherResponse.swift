// WeatherResponse.swift
// AsyncActorKit
// Demonstrates: Codable models, nested decoding, Sendable structs

import Foundation

// MARK: - Top-Level Response

/// Maps exactly to the OpenWeather / rapid-api open-weather13 5-day forecast response.
struct WeatherForecastResponse: Codable, Sendable {
    let cod: String
    let message: Int
    let cnt: Int
    let list: [ForecastItem]
    let city: City
}

// MARK: - ForecastItem

struct ForecastItem: Codable, Sendable, Identifiable {
    let dt: TimeInterval
    let main: MainWeather
    let weather: [WeatherCondition]
    let clouds: Clouds
    let wind: Wind
    let visibility: Int?
    let pop: Double           // Probability of precipitation
    let rain: RainVolume?
    let snow: SnowVolume?
    let sys: ForecastSys
    let dtTxt: String

    var id: TimeInterval { dt }

    enum CodingKeys: String, CodingKey {
        case dt, main, weather, clouds, wind, visibility, pop, rain, snow, sys
        case dtTxt = "dt_txt"
    }

    // MARK: - Computed

    var date: Date { Date(timeIntervalSince1970: dt) }

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }

    var primaryCondition: WeatherCondition? { weather.first }
    var iconURL: URL? {
        guard let icon = primaryCondition?.icon else { return nil }
        return URL(string: "https://openweathermap.org/img/wn/\(icon)@2x.png")
    }
}

// MARK: - Supporting Models

struct MainWeather: Codable, Sendable {
    let temp: Double
    let feelsLike: Double
    let tempMin: Double
    let tempMax: Double
    let pressure: Int
    let seaLevel: Int?
    let grndLevel: Int?
    let humidity: Int
    let tempKf: Double?

    enum CodingKeys: String, CodingKey {
        case temp, pressure, humidity
        case feelsLike = "feels_like"
        case tempMin   = "temp_min"
        case tempMax   = "temp_max"
        case seaLevel  = "sea_level"
        case grndLevel = "grnd_level"
        case tempKf    = "temp_kf"
    }

    /// Temperature in Fahrenheit (API returns °F when lang=EN and units=imperial)
    var tempFahrenheit: Double { temp }
    var tempCelsius: Double    { (temp - 32) * 5 / 9 }
    var feelsCelsius: Double   { (feelsLike - 32) * 5 / 9 }
}

struct WeatherCondition: Codable, Sendable {
    let id: Int
    let main: String
    let description: String
    let icon: String

    var systemImageName: String {
        switch id {
        case 200...232: return "cloud.bolt.rain.fill"
        case 300...321: return "cloud.drizzle.fill"
        case 500...531: return "cloud.rain.fill"
        case 600...622: return "cloud.snow.fill"
        case 701...781: return "cloud.fog.fill"
        case 800:       return icon.hasSuffix("d") ? "sun.max.fill" : "moon.stars.fill"
        case 801...804: return "cloud.fill"
        default:        return "cloud"
        }
    }

    var gradientColors: [String] {
        switch id {
        case 200...232: return ["#1a1a2e", "#4a0e8f"]   // Storm - dark purple
        case 300...531: return ["#1e3c72", "#2a5298"]   // Rain - deep blue
        case 600...622: return ["#e8eaf6", "#9fa8da"]   // Snow - soft indigo
        case 701...781: return ["#4a5568", "#718096"]   // Fog - grey
        case 800:       return ["#f093fb", "#f5576c"]   // Clear - pink/orange
        case 801...802: return ["#4facfe", "#00f2fe"]   // Few clouds - cyan
        case 803...804: return ["#667eea", "#764ba2"]   // Cloudy - purple
        default:        return ["#667eea", "#764ba2"]
        }
    }
}

struct Clouds: Codable, Sendable {
    let all: Int  // Cloudiness, %
}

struct Wind: Codable, Sendable {
    let speed: Double  // m/s
    let deg: Int       // Direction degrees
    let gust: Double?

    var directionLabel: String {
        let directions = ["N","NE","E","SE","S","SW","W","NW"]
        let index = Int((Double(deg) + 22.5) / 45.0) % 8
        return directions[index]
    }

    var speedKmh: Double { speed * 3.6 }
}

struct RainVolume: Codable, Sendable {
    let threeHour: Double?
    enum CodingKeys: String, CodingKey {
        case threeHour = "3h"
    }
}

struct SnowVolume: Codable, Sendable {
    let threeHour: Double?
    enum CodingKeys: String, CodingKey {
        case threeHour = "3h"
    }
}

struct ForecastSys: Codable, Sendable {
    let pod: String // Part of day: d = day, n = night
}

struct City: Codable, Sendable {
    let id: Int
    let name: String
    let coord: Coordinate
    let country: String
    let population: Int
    let timezone: Int
    let sunrise: TimeInterval
    let sunset: TimeInterval

    var sunriseDate: Date { Date(timeIntervalSince1970: sunrise) }
    var sunsetDate: Date  { Date(timeIntervalSince1970: sunset) }
}

struct Coordinate: Codable, Sendable {
    let lat: Double
    let lon: Double
}

// MARK: - Daily Summary (aggregated from 3-hour slots)

struct DailyForecast: Identifiable, Sendable {
    let id: String             // "yyyy-MM-dd"
    let date: Date
    let dayLabel: String
    let items: [ForecastItem]  // All slots for that day

    var minTemp: Double { items.map(\.main.tempMin).min() ?? 0 }
    var maxTemp: Double { items.map(\.main.tempMax).max() ?? 0 }
    var minCelsius: Double { (minTemp - 32) * 5 / 9 }
    var maxCelsius: Double { (maxTemp - 32) * 5 / 9 }
    var dominantCondition: WeatherCondition? { items.first?.primaryCondition }
    var avgHumidity: Int {
        guard !items.isEmpty else { return 0 }
        return items.map(\.main.humidity).reduce(0, +) / items.count
    }
    var avgWindSpeed: Double {
        guard !items.isEmpty else { return 0 }
        return items.map(\.wind.speed).reduce(0, +) / Double(items.count)
    }
    var maxPop: Double { items.map(\.pop).max() ?? 0 }
}

extension WeatherForecastResponse {
    /// Aggregate 3-hourly slots into daily summaries.
    func dailyForecasts() -> [DailyForecast] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var grouped: [String: [ForecastItem]] = [:]
        for item in list {
            let key = String(item.dtTxt.prefix(10))
            grouped[key, default: []].append(item)
        }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"

        return grouped
            .sorted { $0.key < $1.key }
            .compactMap { key, items -> DailyForecast? in
                guard let firstItem = items.first else { return nil }
                return DailyForecast(
                    id: key,
                    date: firstItem.date,
                    dayLabel: dayFormatter.string(from: firstItem.date),
                    items: items.sorted { $0.dt < $1.dt }
                )
            }
    }
}
