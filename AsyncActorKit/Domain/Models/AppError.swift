// AppError.swift
// AsyncActorKit
// Demonstrates: typed error hierarchy, Sendable conformance

import Foundation

/// Typed error hierarchy for the entire application.
/// Using nested enums to categorise errors while keeping them `Sendable` safe.
enum AppError: Error, LocalizedError, Sendable {
    case network(NetworkError)
    case cache(CacheError)
    case location(LocationError)
    case unknown(String)

    // MARK: - Nested Error Types

    enum NetworkError: Error, Sendable {
        case invalidURL
        case invalidResponse
        case unauthorized
        case rateLimited
        case serverError(Int)
        case httpError(Int)
        case decodingFailed(Error)
        case timeout
        case noConnection

        var localizedDescription: String {
            switch self {
            case .invalidURL:          return "Invalid URL configuration."
            case .invalidResponse:     return "Server returned an invalid response."
            case .unauthorized:        return "API key is invalid or missing."
            case .rateLimited:         return "Rate limit exceeded. Please try again later."
            case .serverError(let c):  return "Server error (\(c))."
            case .httpError(let c):    return "HTTP error (\(c))."
            case .decodingFailed(let e): return "Failed to parse response: \(e.localizedDescription)"
            case .timeout:             return "Request timed out."
            case .noConnection:        return "No internet connection."
            }
        }
    }

    enum CacheError: Error, Sendable {
        case notFound
        case expired
        case writeFailed(String)
        case readFailed(String)
    }

    enum LocationError: Error, Sendable {
        case permissionDenied
        case unavailable
        case timeout
    }

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .network(let e):   return e.localizedDescription
        case .cache(let e):
            switch e {
            case .notFound:             return "Data not found in cache."
            case .expired:              return "Cached data has expired."
            case .writeFailed(let r):   return "Cache write failed: \(r)"
            case .readFailed(let r):    return "Cache read failed: \(r)"
            }
        case .location(let e):
            switch e {
            case .permissionDenied: return "Location permission denied."
            case .unavailable:      return "Location unavailable."
            case .timeout:          return "Location request timed out."
            }
        case .unknown(let msg): return msg
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .network(.noConnection): return "Please check your internet connection and try again."
        case .network(.rateLimited):  return "Wait a moment before retrying."
        case .network(.unauthorized): return "Check your API key configuration."
        case .location(.permissionDenied): return "Enable location access in Settings."
        default: return "Please try again."
        }
    }
}
