// RetryPolicy.swift
// AsyncActorKit
// Demonstrates: actor for mutable retry state, exponential backoff, Task.sleep

import Foundation

/// Tracks retry attempts per request using actor isolation for thread safety.
actor RetryPolicy {
    // MARK: - Configuration
    struct Config: Sendable {
        let maxAttempts: Int
        let baseDelay: Duration
        let multiplier: Double
        let jitterRange: ClosedRange<Double>

        static let `default` = Config(
            maxAttempts: 3,
            baseDelay: .milliseconds(500),
            multiplier: 2.0,
            jitterRange: 0.8...1.2
        )
    }

    private let config: Config
    private var attemptCount: Int = 0

    init(config: Config = .default) {
        self.config = config
    }

    // MARK: - Public Interface

    /// Resets the retry counter (call before a fresh request chain).
    func reset() {
        attemptCount = 0
    }

    /// Returns whether another attempt is allowed.
    var canRetry: Bool { attemptCount < config.maxAttempts }

    /// Records an attempt and sleeps for the appropriate back-off duration.
    func recordAttemptAndWait() async throws {
        attemptCount += 1
        let delay = computeDelay()
        await LoggerActor.shared.logNetwork("Retry \(attemptCount)/\(config.maxAttempts) — waiting \(delay)ms")
        try await Task.sleep(for: .milliseconds(delay))
    }

    // MARK: - Private

    private func computeDelay() -> Int {
        let base = Double(config.baseDelay.components.attoseconds) / 1_000_000_000_000_000 // → ms
        let exponential = base * pow(config.multiplier, Double(attemptCount - 1))
        let jitter = Double.random(in: config.jitterRange)
        return Int(exponential * jitter)
    }
}

// MARK: - Convenience wrapper

/// Executes `operation` with automatic retries according to `policy`.
/// Only retries on network/transient errors; propagates all others immediately.
func withRetry<T: Sendable>(
    policy: RetryPolicy = RetryPolicy(),
    operation: @Sendable () async throws -> T
) async throws -> T {
    await policy.reset()
    while true {
        do {
            return try await operation()
        } catch let error as AppError {
            switch error {
            case .network(.timeout), .network(.noConnection), .network(.rateLimited):
                guard await policy.canRetry else { throw error }
                try await policy.recordAttemptAndWait()
            default:
                throw error
            }
        }
    }
}
