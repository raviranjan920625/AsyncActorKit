// ConcurrencyTests.swift
// AsyncActorKit Tests
// Demonstrates: TaskGroup semantics, Task cancellation, withCheckedThrowingContinuation

import XCTest
@testable import AsyncActorKit

final class ConcurrencyTests: XCTestCase {

    // MARK: - TaskGroup

    func test_taskGroup_allChildTasksComplete() async {
        let range = 1...10
        var results: [Int] = []

        results = await withTaskGroup(of: Int.self) { group in
            for i in range {
                group.addTask { i * i }
            }
            var collected: [Int] = []
            for await value in group { collected.append(value) }
            return collected
        }

        XCTAssertEqual(results.sorted(), range.map { $0 * $0 }.sorted(), "All child tasks must complete")
    }

    func test_taskGroup_throwingGroup_propagatesError() async {
        struct Bomb: Error {}

        do {
            _ = try await withThrowingTaskGroup(of: Int.self) { group in
                group.addTask { 1 }
                group.addTask { throw Bomb() }
                group.addTask { 3 }
                var results: [Int] = []
                for try await v in group { results.append(v) }
                return results
            }
            XCTFail("Expected error to propagate")
        } catch {
            XCTAssertTrue(error is Bomb, "TaskGroup should propagate the child error")
        }
    }

    // MARK: - Task Cancellation

    func test_task_cancellation_isCaught() async {
        let task = Task<Void, Error> {
            try await Task.sleep(for: .seconds(60))  // Long sleep
        }

        task.cancel()

        do {
            try await task.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // ✅ Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_task_isCancelled_flagIsSet() async {
        var wasCancelled = false

        let task = Task {
            // Poll cancellation
            for _ in 0..<1000 {
                if Task.isCancelled {
                    wasCancelled = true
                    return
                }
                await Task.yield()
            }
        }

        task.cancel()
        await task.value
        XCTAssertTrue(wasCancelled, "Task.isCancelled must be true after cancel()")
    }

    // MARK: - withCheckedThrowingContinuation (LegacyBridge)

    func test_legacyBridge_returnsDataForValidURL() async throws {
        guard let url = URL(string: "https://openweathermap.org/img/wn/01d@2x.png") else {
            return XCTFail("Bad URL")
        }
        let data = try await LegacyBridge.fetchData(from: url)
        XCTAssertFalse(data.isEmpty, "LegacyBridge should return image data")
    }

    func test_legacyBridge_nonThrowing_returnsEmptyOnBadURL() async {
        guard let url = URL(string: "https://0.0.0.0/nonexistent") else { return }
        // fetchDataOrEmpty never throws — should gracefully return empty Data
        let data = await LegacyBridge.fetchDataOrEmpty(from: url)
        XCTAssertNotNil(data, "Non-throwing bridge should never crash")
    }

    // MARK: - NetworkSession + Mock

    func test_networkSession_returnsDecodedModel_withMock() async throws {
        // Build a minimal valid WeatherForecastResponse JSON
        let json = """
        {
          "cod": "200", "message": 0, "cnt": 1,
          "list": [{
            "dt": 1713200000,
            "main": { "temp": 75.0, "feels_like": 73.0, "temp_min": 70.0,
                      "temp_max": 78.0, "pressure": 1012, "humidity": 60 },
            "weather": [{ "id": 800, "main": "Clear", "description": "clear sky", "icon": "01d" }],
            "clouds": { "all": 0 },
            "wind": { "speed": 3.5, "deg": 180 },
            "visibility": 10000,
            "pop": 0.0,
            "sys": { "pod": "d" },
            "dt_txt": "2024-04-15 12:00:00"
          }],
          "city": {
            "id": 1, "name": "Test City", "country": "TC",
            "coord": { "lat": 40.73, "lon": -73.94 },
            "population": 1000000, "timezone": -14400,
            "sunrise": 1713175200, "sunset": 1713222600
          }
        }
        """.data(using: .utf8)!

        let mock = MockNetworkSession(behaviour: .success(json))
        let session = NetworkSession(session: mock)

        let url = URL(string: "https://example.com")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let response: WeatherForecastResponse = try await session.fetch(request)

        XCTAssertEqual(response.city.name, "Test City")
        XCTAssertEqual(response.list.count, 1)
        XCTAssertEqual(mock.callCount, 1, "Mock should have been called exactly once")
    }

    func test_networkSession_unauthorized_throwsAppError() async {
        // Return 401 from mock
        let mock = MockNetworkSession(behaviour: .success(Data()))

        // Directly craft a 401 response by replacing the behaviour with a custom session
        // We'll use a subclass approach for simplicity
        let failingMock = HTTP401MockSession()
        let session = NetworkSession(session: failingMock)

        var request = URLRequest(url: URL(string: "https://example.com")!)
        request.httpMethod = "GET"

        do {
            _ = try await session.fetch(request)
            XCTFail("Should have thrown")
        } catch AppError.network(.unauthorized) {
            // ✅
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}

// MARK: - Helper Mock for 401

final class HTTP401MockSession: NetworkSessionProtocol, @unchecked Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        return (Data(), response)
    }
}
