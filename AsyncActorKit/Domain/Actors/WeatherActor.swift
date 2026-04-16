// WeatherActor.swift
// AsyncActorKit
// Demonstrates: core actor isolation, reentrancy, private mutable state

import Foundation

/// Isolated actor that owns weather data processing.
/// No external code can touch `lastFetch` or `processingCount` without going through the actor.
actor WeatherActor {

    // MARK: - Isolated State (cannot be accessed without await)
    private(set) var lastFetch: Date?
    private(set) var processingCount: Int = 0
    private let apiClient: RapidAPIClient

    // MARK: - Init
    init(apiClient: RapidAPIClient = RapidAPIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Public Interface

    /// Fetches a forecast. Increments processingCount before the await suspension
    /// point and decrements after — demonstrating reentrancy-safe bookkeeping.
    func fetchForecast(lat: Double, lon: Double) async throws -> WeatherForecastResponse {
        processingCount += 1
        defer { processingCount -= 1 }

        await LoggerActor.shared.logWeather("WeatherActor: fetching for (\(lat), \(lon)), active tasks: \(processingCount)")

        // ← Suspension point: actor is reentrant here, other callers may proceed
        let response = try await apiClient.fetchFiveDayForecast(latitude: lat, longitude: lon)

        // Back on actor — state mutation is safe again
        lastFetch = Date()
        await LoggerActor.shared.logWeather("WeatherActor: fetch complete, items: \(response.list.count)")
        return response
    }

    /// Demonstrates that isolated state is indeed isolated.
    func diagnostics() -> String {
        let fetchStr = lastFetch.map { "Last fetch: \($0)" } ?? "Never fetched"
        return "\(fetchStr) | Active tasks: \(processingCount)"
    }
}
