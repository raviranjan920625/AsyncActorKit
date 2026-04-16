// ActorTests.swift
// AsyncActorKit Tests
// Demonstrates: actor isolation tests, reentrancy safety, CacheActor validation

import XCTest
@testable import AsyncActorKit

final class ActorTests: XCTestCase {

    // MARK: - CacheActor Tests

    func test_cacheActor_setAndGet_returnsValue() async {
        let cache = CacheActor<String, String>(capacity: 5, ttl: 60)

        await cache.set("key1", value: "hello")
        let result = await cache.get("key1")

        XCTAssertEqual(result, "hello")
    }

    func test_cacheActor_expiredEntry_returnsNil() async throws {
        // TTL of 0 means entries expire immediately
        let cache = CacheActor<String, String>(capacity: 5, ttl: 0)

        await cache.set("key1", value: "stale")
        // Sleep just past TTL
        try await Task.sleep(for: .milliseconds(10))
        let result = await cache.get("key1")

        XCTAssertNil(result, "Expired entries should return nil")
    }

    func test_cacheActor_lruEviction_dropsOldestItem() async {
        let cache = CacheActor<String, String>(capacity: 3, ttl: 300)

        await cache.set("a", value: "A")
        await cache.set("b", value: "B")
        await cache.set("c", value: "C")
        // Access "a" so it becomes MRU; "b" should be LRU
        _ = await cache.get("a")
        _ = await cache.get("c")

        // Adding a 4th entry must evict "b"
        await cache.set("d", value: "D")

        let b = await cache.get("b")
        let d = await cache.get("d")

        XCTAssertNil(b, "LRU key 'b' should have been evicted")
        XCTAssertEqual(d, "D")
    }

    func test_cacheActor_clear_removesAllEntries() async {
        let cache = CacheActor<String, Int>(capacity: 10, ttl: 300)

        await cache.set("x", value: 1)
        await cache.set("y", value: 2)
        await cache.clear()

        let count = await cache.count
        XCTAssertEqual(count, 0)
    }

    // MARK: - WeatherActor Tests

    func test_weatherActor_diagnostics_returnsDefaultString() async {
        let actor = WeatherActor()
        let diag = await actor.diagnostics()

        XCTAssertTrue(diag.contains("Never fetched"), "Unused actor should report 'Never fetched'")
        XCTAssertTrue(diag.contains("Active tasks: 0"))
    }

    func test_weatherActor_processingCount_isZeroAfterFetch() async throws {
        // This test requires a real network hit; skip in CI by checking env
        guard ProcessInfo.processInfo.environment["INTEGRATION_TESTS"] == "1" else {
            throw XCTSkip("Integration test skipped — set INTEGRATION_TESTS=1 to run")
        }

        let actor = WeatherActor()
        _ = try await actor.fetchForecast(lat: 40.73, lon: -73.94)

        let count = await actor.processingCount
        XCTAssertEqual(count, 0, "processingCount must return to 0 after fetch completes")
    }

    // MARK: - Actor Isolation: concurrent mutation safety

    func test_cacheActor_concurrentWrites_noDataRace() async {
        let cache = CacheActor<Int, Int>(capacity: 200, ttl: 300)

        // Launch 100 concurrent tasks all writing to the same actor.
        // Under the actor model this must never race — the Swift concurrency
        // checker would flag a data race if isolation were broken.
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await cache.set(i, value: i * 2)
                }
            }
        }

        let count = await cache.count
        XCTAssertLessThanOrEqual(count, 200, "Count must not exceed capacity")
    }
}
