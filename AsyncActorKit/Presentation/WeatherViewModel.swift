// WeatherViewModel.swift
// AsyncActorKit
// Demonstrates: @Observable @MainActor, Task cancellation, structured concurrency

import Foundation
import Observation

// MARK: - View State

enum LoadingState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

// MARK: - ViewModel

@MainActor
@Observable
final class WeatherViewModel {

    // MARK: - Published State (auto-observed via @Observable macro)
    var forecast: WeatherForecastResponse?
    var dailyForecasts: [DailyForecast] = []
    var selectedDay: DailyForecast?
    var loadingState: LoadingState = .idle
    var actorDiagnostics: String = ""
    var showConcurrencyDemo: Bool = false

    // MARK: - Configuration
    var latitude: Double  = 23.344100    // Jharkhand (default)
    var longitude: Double = 85.309600

    // MARK: - Dependencies
    private let repository: any WeatherRepositoryProtocol
    private let weatherActor: WeatherActor

    // MARK: - Task Management (structured cancellation)
    private var loadTask: Task<Void, Never>?

    init(
        repository: any WeatherRepositoryProtocol = WeatherRepository(),
        weatherActor: WeatherActor = WeatherActor()
    ) {
        self.repository = repository
        self.weatherActor = weatherActor
    }

    // MARK: - Public Actions

    func loadForecast() {
        // Cancel any in-flight fetch before starting a new one
        loadTask?.cancel()

        loadTask = Task {
            await performLoad()
        }
    }

    func refresh() async {
        await repository.clearCache()
        loadForecast()
    }

    func selectDay(_ day: DailyForecast) {
        selectedDay = day
    }

    func updateDiagnostics() async {
        actorDiagnostics = await weatherActor.diagnostics()
    }

    // MARK: - Concurrency Demo (TaskGroup fan-out)

    /// Demonstrates TaskGroup by fetching multiple city forecasts concurrently.
    func runConcurrencyDemo() async -> [String: Int] {
        let cities: [(name: String, lat: Double, lon: Double)] = [
            ("New York",   40.73,  -73.94),
            ("London",     51.51,  -0.13),
            ("Tokyo",      35.68,  139.69),
            ("Sydney",    -33.87,  151.21),
        ]

        showConcurrencyDemo = true
        defer { showConcurrencyDemo = false }

        return await withTaskGroup(of: (String, Int).self) { group in
            for city in cities {
                group.addTask {
                    do {
                        let result = try await self.repository.fetchForecast(lat: city.lat, lon: city.lon)
                        return (city.name, result.cnt)
                    } catch {
                        return (city.name, 0)
                    }
                }
            }

            var results: [String: Int] = [:]
            for await (name, count) in group {
                results[name] = count
            }
            return results
        }
    }

    // MARK: - Private

    private func performLoad() async {
        guard !Task.isCancelled else { return }
        loadingState = .loading

        do {
            let response = try await repository.fetchForecast(lat: latitude, lon: longitude)

            // Check for cancellation after the suspension point
            guard !Task.isCancelled else { return }

            forecast = response
            dailyForecasts = response.dailyForecasts()
            selectedDay = dailyForecasts.first
            loadingState = .loaded
            await updateDiagnostics()

        } catch is CancellationError {
            loadingState = .idle
        } catch {
            loadingState = .failed(error.localizedDescription)
            await LoggerActor.shared.logError(error, context: "WeatherViewModel.performLoad")
        }
    }
}
