// DiskCacheService.swift
// AsyncActorKit
// Demonstrates: async file I/O, actor isolation for disk operations

import Foundation

/// Actor that serialises all disk-cache reads and writes.
/// Demonstrates async file I/O using structured concurrency.
actor DiskCacheService {

    private let cacheDirectory: URL
    private let fileManager = FileManager.default

    init(subdirectory: String = "WeatherCache") {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent(subdirectory, isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Interface

    /// Persist an encodable value to disk under `key`.
    func write<T: Encodable>(_ value: T, forKey key: String) async throws {
        let fileURL = url(for: key)
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL, options: .atomic)
            await LoggerActor.shared.logCache("Wrote \(data.count) bytes → \(key)")
        } catch {
            throw AppError.cache(.writeFailed(error.localizedDescription))
        }
    }

    /// Read and decode a value from disk for `key`.
    func read<T: Decodable>(_ type: T.Type, forKey key: String) async throws -> T {
        let fileURL = url(for: key)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw AppError.cache(.notFound)
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let value = try JSONDecoder().decode(T.self, from: data)
            await LoggerActor.shared.logCache("Read \(data.count) bytes ← \(key)")
            return value
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.cache(.readFailed(error.localizedDescription))
        }
    }

    /// Delete a cached file.
    func delete(forKey key: String) async {
        try? fileManager.removeItem(at: url(for: key))
    }

    /// Remove all cached files.
    func clearAll() async {
        let contents = (try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        contents.forEach { try? fileManager.removeItem(at: $0) }
        await LoggerActor.shared.logCache("Cleared \(contents.count) cached files")
    }

    // MARK: - Private

    private func url(for key: String) -> URL {
        // Use a safe filename
        let safeKey = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return cacheDirectory.appendingPathComponent("\(safeKey).json")
    }
}
