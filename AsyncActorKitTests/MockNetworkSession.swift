// MockNetworkSession.swift
// AsyncActorKit Tests
// Demonstrates: async mock for protocols, test isolation

import Foundation
@testable import AsyncActorKit

/// In-memory mock that conforms to NetworkSessionProtocol.
/// Lets tests inject canned responses without hitting the network.
final class MockNetworkSession: NetworkSessionProtocol, @unchecked Sendable {

    // MARK: - Configuration
    indirect enum Behaviour {
        case success(Data)
        case failure(Error)
        case delay(seconds: Double, then: Behaviour)
    }

    var behaviour: Behaviour
    private(set) var callCount = 0
    private(set) var lastRequest: URLRequest?

    init(behaviour: Behaviour = .success(Data())) {
        self.behaviour = behaviour
    }

    // MARK: - NetworkSessionProtocol

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        callCount += 1
        lastRequest = request

        switch behaviour {
        case .success(let data):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response)

        case .failure(let error):
            throw error

        case .delay(let seconds, let next):
            try await Task.sleep(for: .seconds(seconds))
            behaviour = next
            return try await data(for: request)
        }
    }

    // MARK: - Helpers

    static func makeSession(with response: Encodable) throws -> MockNetworkSession {
        let data = try JSONEncoder().encode(response)
        return MockNetworkSession(behaviour: .success(data))
    }
}
