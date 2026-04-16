// CacheActor.swift
// AsyncActorKit
// Demonstrates: actor isolation for mutable collections, LRU eviction, generic caching

import Foundation

/// Thread-safe, in-memory LRU cache implemented as a Swift actor.
/// Demonstrates actor reentrancy safety and isolated mutable state.
actor CacheActor<Key: Hashable & Sendable, Value: Sendable> {

    // MARK: - Types
    private struct Entry {
        let value: Value
        let expiry: Date
        var lastAccessed: Date

        var isExpired: Bool { Date() > expiry }
    }

    // MARK: - State
    private var store: [Key: Entry] = [:]
    private var accessOrder: [Key] = []   // front = MRU, back = LRU
    private let capacity: Int
    private let ttl: TimeInterval

    // MARK: - Init
    init(capacity: Int = 50, ttl: TimeInterval = 300) {
        self.capacity = capacity
        self.ttl = ttl
    }

    // MARK: - Interface

    /// Retrieves a cached value if it exists and hasn't expired.
    func get(_ key: Key) -> Value? {
        guard var entry = store[key] else { return nil }
        guard !entry.isExpired else {
            evict(key)
            return nil
        }
        // Update LRU order
        entry.lastAccessed = Date()
        store[key] = entry
        promote(key)
        return entry.value
    }

    /// Stores a value with the default TTL.
    func set(_ key: Key, value: Value) {
        if store[key] != nil {
            evict(key)
        }
        if store.count >= capacity {
            evictLRU()
        }
        store[key] = Entry(value: value, expiry: Date().addingTimeInterval(ttl), lastAccessed: Date())
        accessOrder.insert(key, at: 0)
    }

    /// Removes a specific key.
    func remove(_ key: Key) {
        evict(key)
    }

    /// Clears all entries.
    func clear() {
        store.removeAll()
        accessOrder.removeAll()
    }

    /// Returns the number of cached items.
    var count: Int { store.count }

    // MARK: - Private

    private func evict(_ key: Key) {
        store.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }

    private func evictLRU() {
        guard let lruKey = accessOrder.last else { return }
        evict(lruKey)
    }

    private func promote(_ key: Key) {
        accessOrder.removeAll { $0 == key }
        accessOrder.insert(key, at: 0)
    }
}
