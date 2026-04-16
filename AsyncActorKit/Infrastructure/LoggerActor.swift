// LoggerActor.swift
// AsyncActorKit
// Demonstrates: @globalActor, custom global actor isolation

import Foundation
import os.log

/// A global actor that serializes all logging operations.
/// Demonstrates the @globalActor pattern for singletons that need isolation.
@globalActor
actor LoggerActor {
    static let shared = LoggerActor()

    private let weatherLogger = Logger(subsystem: "com.asyncactorkit", category: "Weather")
    private let networkLogger = Logger(subsystem: "com.asyncactorkit", category: "Network")
    private let cacheLogger   = Logger(subsystem: "com.asyncactorkit", category: "Cache")

    // MARK: - Logging Interface

    func logWeather(_ message: String, level: OSLogType = .info) {
        weatherLogger.log(level: level, "\(message, privacy: .public)")
    }

    func logNetwork(_ message: String, level: OSLogType = .info) {
        networkLogger.log(level: level, "\(message, privacy: .public)")
    }

    func logCache(_ message: String, level: OSLogType = .info) {
        cacheLogger.log(level: level, "\(message, privacy: .public)")
    }

    func logError(_ error: Error, context: String = "") {
        let msg = context.isEmpty ? "\(error)" : "[\(context)] \(error)"
        weatherLogger.error("\(msg, privacy: .public)")
    }
}
