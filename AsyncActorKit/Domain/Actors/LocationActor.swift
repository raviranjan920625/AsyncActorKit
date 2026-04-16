// LocationActor.swift
// AsyncActorKit
// Demonstrates: AsyncStream bridging CLLocationManager, nonisolated delegate trampoline

import Foundation
import CoreLocation

// MARK: - LocationActor

/// Actor that owns location-stream state, isolated from the CLLocationManager delegate.
/// The delegate itself is a plain class (CLLocationManagerDelegate requires NSObject),
/// and it trampolines all callbacks back into the actor via Task { await actor.xxx() }.
actor LocationActor {

    // MARK: - State
    private var streamContinuation: AsyncStream<CLLocation>.Continuation?
    private var singleContinuation: CheckedContinuation<CLLocation, Error>?
    private var locationManager: CLLocationManager?
    private lazy var delegate = LocationDelegate(owner: self)

    // MARK: - Public Interface

    /// Returns an AsyncStream that emits location updates.
    func locationStream() -> AsyncStream<CLLocation> {
        AsyncStream { [weak self] continuation in
            guard let self else { continuation.finish(); return }
            Task {
                await self.configureStream(continuation: continuation)
            }
        }
    }

    /// One-shot: resolves with the next available location.
    func requestCurrentLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await self.configureSingleLocation(continuation: continuation)
            }
        }
    }

    func stopUpdating() {
        locationManager?.stopUpdatingLocation()
        streamContinuation?.finish()
        streamContinuation = nil
    }

    // MARK: - Internal callbacks (called by delegate trampoline)

    func receive(location: CLLocation) {
        streamContinuation?.yield(location)
        if let sc = singleContinuation {
            sc.resume(returning: location)
            singleContinuation = nil
            locationManager?.stopUpdatingLocation()
        }
    }

    func receiveError(_ error: Error) {
        singleContinuation?.resume(throwing: AppError.location(.unavailable))
        singleContinuation = nil
        streamContinuation?.finish()
    }

    func authorizationChanged(status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager?.startUpdatingLocation()
        case .denied, .restricted:
            singleContinuation?.resume(throwing: AppError.location(.permissionDenied))
            singleContinuation = nil
            streamContinuation?.finish()
        default:
            break
        }
    }

    // MARK: - Private setup

    private func configureStream(continuation: AsyncStream<CLLocation>.Continuation) {
        self.streamContinuation = continuation
        startManager()

        continuation.onTermination = { @Sendable [weak self] _ in
            Task { await self?.stopUpdating() }
        }
    }

    private func configureSingleLocation(continuation: CheckedContinuation<CLLocation, Error>) {
        self.singleContinuation = continuation
        startManager()
    }

    private func startManager() {
        let mgr = CLLocationManager()
        mgr.delegate = delegate
        mgr.desiredAccuracy = kCLLocationAccuracyHundredMeters
        self.locationManager = mgr

        switch mgr.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            mgr.startUpdatingLocation()
        case .notDetermined:
            mgr.requestWhenInUseAuthorization()
        default:
            streamContinuation?.finish()
        }
    }
}

// MARK: - Delegate Trampoline (NSObject subclass, nonisolated bridge)

/// Plain NSObject subclass that holds a weak reference to the actor and
/// trampolines all delegate calls back into it via unstructured Tasks.
private final class LocationDelegate: NSObject, CLLocationManagerDelegate {
    private weak var owner: LocationActor?

    init(owner: LocationActor) { self.owner = owner }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { await owner?.receive(location: location) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { await owner?.receiveError(error) }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { await owner?.authorizationChanged(status: manager.authorizationStatus) }
    }
}
