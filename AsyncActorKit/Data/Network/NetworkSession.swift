// NetworkSession.swift
// AsyncActorKit
// Demonstrates: async/await URLSession wrapper, protocol-based design for testability

import Foundation

// MARK: - Protocol (enables mocking in tests)

protocol NetworkSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSessionProtocol {}

// MARK: - NetworkSession

/// Wraps URLSession with async/await and validates HTTP responses.
/// All methods are async and throw typed `AppError`.
struct NetworkSession: Sendable {
    private let session: any NetworkSessionProtocol

    init(session: any NetworkSessionProtocol = URLSession.shared) {
        self.session = session
    }

    /// Fetches data for a request, validates HTTP status, and returns raw Data.
    func fetch(_ request: URLRequest) async throws -> Data {
        await LoggerActor.shared.logNetwork("→ \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.network(.invalidResponse)
        }

        await LoggerActor.shared.logNetwork("← \(httpResponse.statusCode) (\(data.count) bytes)")

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw AppError.network(.unauthorized)
        case 429:
            throw AppError.network(.rateLimited)
        case 500...:
            throw AppError.network(.serverError(httpResponse.statusCode))
        default:
            throw AppError.network(.httpError(httpResponse.statusCode))
        }
    }

    /// Convenience: decode JSON directly
    func fetch<T: Decodable>(_ request: URLRequest, as type: T.Type = T.self) async throws -> T {
        let data = try await fetch(request)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AppError.network(.decodingFailed(error))
        }
    }
}
