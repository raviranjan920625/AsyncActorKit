// WeatherRepositoryProtocol.swift
// AsyncActorKit
// Demonstrates: protocol-based abstraction for async repositories

import Foundation

/// Abstraction over weather data source, enabling easy mocking and testing.
protocol WeatherRepositoryProtocol: Sendable {
    /// Fetch a 5-day forecast for given coordinates.
    func fetchForecast(lat: Double, lon: Double) async throws -> WeatherForecastResponse

    /// Clear any cached data.
    func clearCache() async
}
