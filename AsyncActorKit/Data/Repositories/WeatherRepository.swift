// WeatherRepository.swift
// AsyncActorKit
// Demonstrates: async throws, cache-then-network strategy, error mapping

import Foundation

/// Concrete implementation of WeatherRepositoryProtocol.
/// Uses a cache-first strategy: returns cached data immediately while
/// refreshing from the network in the background.
final class WeatherRepository: WeatherRepositoryProtocol {

    private let weatherActor: WeatherActor
    private let memCache: CacheActor<String, WeatherForecastResponse>
    private let diskCache: DiskCacheService

    init(
        weatherActor: WeatherActor = WeatherActor(),
        memCache: CacheActor<String, WeatherForecastResponse> = CacheActor(capacity: 10, ttl: 300),
        diskCache: DiskCacheService = DiskCacheService()
    ) {
        self.weatherActor = weatherActor
        self.memCache = memCache
        self.diskCache = diskCache
    }

    // MARK: - WeatherRepositoryProtocol

    func fetchForecast(lat: Double, lon: Double) async throws -> WeatherForecastResponse {
        let cacheKey = cacheKey(lat: lat, lon: lon)

        // 1. Try memory cache (instant — no suspension)
        if let cached = await memCache.get(cacheKey) {
            await LoggerActor.shared.logCache("Memory cache hit: \(cacheKey)")
            return cached
        }

        // 2. Try disk cache
        if let diskHit = try? await diskCache.read(WeatherForecastResponse.self, forKey: cacheKey) {
            await LoggerActor.shared.logCache("Disk cache hit: \(cacheKey)")
            await memCache.set(cacheKey, value: diskHit)
            return diskHit
        }

        // 3. Fetch from network
        await LoggerActor.shared.logNetwork("Cache miss — fetching from network")
        let response = try await weatherActor.fetchForecast(lat: lat, lon: lon)

        // 4. Persist to both caches
        await memCache.set(cacheKey, value: response)
        try? await diskCache.write(response, forKey: cacheKey)

        return response
    }

    func clearCache() async {
        await memCache.clear()
        await diskCache.clearAll()
    }

    // MARK: - Private

    private func cacheKey(lat: Double, lon: Double) -> String {
        // Round to 2 decimal places to de-duplicate nearby requests
        String(format: "forecast_%.2f_%.2f", lat, lon)
    }
}
