// LegacyBridge.swift
// AsyncActorKit
// Demonstrates: withCheckedThrowingContinuation, bridging callback APIs to async/await

import Foundation

/// Shows how to wrap a hypothetical legacy callback-based SDK into async/await.
/// In a real project this would wrap URLSession.dataTask or a third-party SDK.
enum LegacyBridge {

    // MARK: - Simulated legacy callback API

    typealias LegacyCompletion = (Data?, Error?) -> Void

    /// Simulates a fictional SDK function that uses completion handlers.
    private static func legacyFetch(url: URL, completion: @escaping LegacyCompletion) {
        // Simulates an async callback (e.g. old URLSession.dataTask pattern)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            URLSession.shared.dataTask(with: url) { data, _, error in
                completion(data, error)
            }.resume()
        }
    }

    // MARK: - async/await Bridge

    /// Wraps the legacy callback into a modern `async throws` function.
    /// This is the canonical pattern for bridging any delegate / completion-handler API.
    static func fetchData(from url: URL) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            legacyFetch(url: url) { data, error in
                if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? AppError.network(.invalidResponse))
                }
            }
        }
    }

    // MARK: - withCheckedContinuation (non-throwing variant)

    /// Wraps a non-throwing legacy operation (e.g. file read) that always succeeds.
    static func fetchDataOrEmpty(from url: URL) async -> Data {
        return await withCheckedContinuation { continuation in
            legacyFetch(url: url) { data, _ in
                continuation.resume(returning: data ?? Data())
            }
        }
    }
}
