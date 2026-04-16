// RapidAPIClient.swift
// AsyncActorKit
// Demonstrates: Structured API client, URLRequest building, actor isolation

import Foundation

/// Concrete HTTP client for the open-weather13 RapidAPI endpoint.
struct RapidAPIClient: Sendable {

    // MARK: - Constants
    private static let host    = "open-weather13.p.rapidapi.com"
    private static let apiKey  = "7ad86f5233mshc68a7bd5712602fp10b021jsn4b92813befc6"
    private static let baseURL = "https://open-weather13.p.rapidapi.com"

    private let networkSession: NetworkSession

    init(networkSession: NetworkSession = NetworkSession()) {
        self.networkSession = networkSession
    }

    // MARK: - Public API

    /// Fetches a 5-day, 3-hourly forecast for the given coordinates.
    func fetchFiveDayForecast(latitude: Double, longitude: Double, lang: String = "EN") async throws -> WeatherForecastResponse {
        let urlString = "\(Self.baseURL)/fivedaysforcast?latitude=\(latitude)&longitude=\(longitude)&lang=\(lang)"
        guard let url = URL(string: urlString) else {
            throw AppError.network(.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.host, forHTTPHeaderField: "x-rapidapi-host")
        request.setValue(Self.apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.timeoutInterval = 15

        await LoggerActor.shared.logNetwork("Fetching forecast — lat:\(latitude), lon:\(longitude)")
        return try await networkSession.fetch(request, as: WeatherForecastResponse.self)
    }
}
