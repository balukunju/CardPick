import CoreLocation
import MapKit
import CardPickCore

struct LocatedPlace: Equatable {
    var name: String?
    var poiCategoryRaw: String?
    var rewardCategory: RewardCategory
    var latitude: Double
    var longitude: Double

    var kindName: String? {
        guard let poiCategoryRaw else { return nil }
        return POICategoryMapping.placeKindName(forPOIRawValue: poiCategoryRaw)
    }
}

enum PlaceError: Error {
    /// The shortcut ran before the app had a chance to ask for location.
    case needsPermissionInApp
    case denied
    case unavailable
}

@MainActor
final class PlaceLocator: NSObject, CLLocationManagerDelegate {
    static let shared = PlaceLocator()

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var chain: Task<LocatedPlace, Error>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    /// Calls run one at a time so the location manager has a single waiter.
    /// The shortcut passes `promptIfNeeded: false` so it never sits on a system
    /// alert the user cannot see.
    func locate(promptIfNeeded: Bool) async throws -> LocatedPlace {
        let previous = chain
        let run = Task { @MainActor () throws -> LocatedPlace in
            if let previous {
                _ = try? await previous.value
            }
            return try await self.locateOnce(promptIfNeeded: promptIfNeeded)
        }
        chain = run
        return try await run.value
    }

    private func locateOnce(promptIfNeeded: Bool) async throws -> LocatedPlace {
        let status = try await authorization(promptIfNeeded: promptIfNeeded)
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .notDetermined:
            throw PlaceError.needsPermissionInApp
        default:
            throw PlaceError.denied
        }
        let location = try await requestLocation()
        return await nearestPlace(to: location)
    }

    private func authorization(promptIfNeeded: Bool) async throws -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        if current != .notDetermined {
            return current
        }
        guard promptIfNeeded else {
            throw PlaceError.needsPermissionInApp
        }
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    private func requestLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
            timeoutTask?.cancel()
            timeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if Task.isCancelled { return }
                self.finishLocation(.failure(PlaceError.unavailable))
            }
        }
    }

    private func finishLocation(_ result: Result<CLLocation, Error>) {
        timeoutTask?.cancel()
        timeoutTask = nil
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(with: result)
    }

    private func finishAuthorization(_ status: CLAuthorizationStatus) {
        guard let continuation = authorizationContinuation else { return }
        authorizationContinuation = nil
        continuation.resume(returning: status)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard status != .notDetermined else { return }
            self.finishAuthorization(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.finishLocation(.success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.finishLocation(.failure(PlaceError.unavailable))
        }
    }

    private func nearestPlace(to location: CLLocation) async -> LocatedPlace {
        let radii: [CLLocationDistance] = [80, 200, 500]
        for radius in radii {
            if let found = await search(around: location, radius: radius) {
                return found
            }
        }
        return LocatedPlace(
            name: nil,
            poiCategoryRaw: nil,
            rewardCategory: .other,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    private func search(around location: CLLocation, radius: CLLocationDistance) async -> LocatedPlace? {
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: radius)
        request.pointOfInterestFilter = .includingAll
        let search = MKLocalSearch(request: request)
        let response: MKLocalSearch.Response
        do {
            response = try await search.start()
        } catch {
            return nil
        }

        let ranked = response.mapItems.compactMap { item -> (MKMapItem, CLLocationDistance)? in
            let coordinate = item.placemark.coordinate
            guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
            let hasName = !(item.name ?? item.placemark.name ?? "").isEmpty
            guard hasName || item.pointOfInterestCategory != nil else { return nil }
            let spot = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return (item, location.distance(from: spot))
        }
        .sorted { $0.1 < $1.1 }

        guard let nearest = ranked.first?.0 else { return nil }
        let raw = nearest.pointOfInterestCategory?.rawValue
        let name = nearest.name ?? nearest.placemark.name
        let reward = raw.map(POICategoryMapping.rewardCategory(forPOIRawValue:)) ?? .other
        return LocatedPlace(
            name: name,
            poiCategoryRaw: raw,
            rewardCategory: reward,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
}
