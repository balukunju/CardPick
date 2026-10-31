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

    var hasPlaceIdentity: Bool {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !trimmed.isEmpty || poiCategoryRaw != nil
    }
}

enum LocationProblem: Equatable {
    case needsPermissionInApp
    case denied
    case unavailable
    case noPlace
}

struct PlaceLookup: Equatable {
    var place: LocatedPlace?
    var problem: LocationProblem?
}

private enum PlaceError: Error {
    case needsPermissionInApp
    case denied
    case unavailable
}

@MainActor
final class PlaceLocator: NSObject, CLLocationManagerDelegate {
    static let shared = PlaceLocator()

    /// A fix arrived, including one that shows up after a timed-out attempt.
    var onResolvedFix: (@MainActor (CLLocation) -> Void)?
    var onAuthorizationChange: (@MainActor (CLAuthorizationStatus) -> Void)?

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locateContinuation: CheckedContinuation<PlaceLookup, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var locationTimeout: Task<Void, Never>?
    private var authorizationTimeout: Task<Void, Never>?
    private var generation = 0
    private var lastFix: CLLocation?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    /// The shortcut passes `promptIfNeeded: false` so it never waits on a system
    /// alert the user cannot see. A missing fix ends in about 12 seconds. The
    /// whole attempt, including a slow place search, ends within 45 seconds.
    func locate(promptIfNeeded: Bool) async -> PlaceLookup {
        deadlineTask?.cancel()
        generation += 1
        let token = generation
        failPendingWaits()
        finishLocate(PlaceLookup(place: nil, problem: .unavailable))

        return await withCheckedContinuation { continuation in
            locateContinuation = continuation
            deadlineTask = Task.detached {
                try? await Task.sleep(for: .seconds(45))
                guard !Task.isCancelled else { return }
                await PlaceLocator.shared.deadlineFired(token: token)
            }
            Task { @MainActor in
                let value = await self.locateOnce(promptIfNeeded: promptIfNeeded, token: token)
                guard token == self.generation else { return }
                self.finishLocate(value)
            }
        }
    }

    private func locateOnce(promptIfNeeded: Bool, token: Int) async -> PlaceLookup {
        guard token == generation else { return PlaceLookup(place: nil, problem: .unavailable) }

        let status: CLAuthorizationStatus
        do {
            status = try await authorization(promptIfNeeded: promptIfNeeded)
        } catch let error as PlaceError {
            return PlaceLookup(place: nil, problem: problem(for: error))
        } catch {
            return PlaceLookup(place: nil, problem: .unavailable)
        }
        guard token == generation else { return PlaceLookup(place: nil, problem: .unavailable) }

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .notDetermined:
            return PlaceLookup(place: nil, problem: .needsPermissionInApp)
        case .denied, .restricted:
            return PlaceLookup(place: nil, problem: .denied)
        @unknown default:
            return PlaceLookup(place: nil, problem: .unavailable)
        }

        let location: CLLocation
        do {
            location = try await requestLocation()
        } catch let error as PlaceError {
            return PlaceLookup(place: nil, problem: problem(for: error))
        } catch {
            return PlaceLookup(place: nil, problem: .unavailable)
        }
        guard token == generation else { return PlaceLookup(place: nil, problem: .unavailable) }

        guard let found = await nearestPlace(to: location) else {
            return PlaceLookup(
                place: LocatedPlace(
                    name: nil,
                    poiCategoryRaw: nil,
                    rewardCategory: .other,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                ),
                problem: .noPlace
            )
        }
        return PlaceLookup(place: found, problem: nil)
    }

    /// Every authorization state is handled here. `.notDetermined` always calls
    /// `requestWhenInUseAuthorization` and waits for the change callback.
    private func authorization(promptIfNeeded: Bool) async throws -> CLAuthorizationStatus {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return manager.authorizationStatus
        case .denied, .restricted:
            throw PlaceError.denied
        case .notDetermined:
            break
        @unknown default:
            throw PlaceError.unavailable
        }

        guard promptIfNeeded else {
            throw PlaceError.needsPermissionInApp
        }

        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
            let status = manager.authorizationStatus
            if status != .notDetermined {
                finishAuthorization(status)
            }
            authorizationTimeout?.cancel()
            let token = generation
            authorizationTimeout = Task.detached {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                await PlaceLocator.shared.authorizationTimedOut(token: token)
            }
        }
    }

    private func requestLocation() async throws -> CLLocation {
        if let cached = freshCachedLocation() {
            return cached
        }
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
            locationTimeout?.cancel()
            let token = generation
            locationTimeout = Task.detached {
                try? await Task.sleep(for: .seconds(12))
                guard !Task.isCancelled else { return }
                await PlaceLocator.shared.locationTimedOut(token: token)
            }
        }
    }

    private func freshCachedLocation() -> CLLocation? {
        let candidate = lastFix ?? manager.location
        guard let candidate else { return nil }
        guard candidate.horizontalAccuracy >= 0 else { return nil }
        guard CLLocationCoordinate2DIsValid(candidate.coordinate) else { return nil }
        guard abs(candidate.timestamp.timeIntervalSinceNow) < 30 else { return nil }
        return candidate
    }

    private func nearestPlace(to location: CLLocation) async -> LocatedPlace? {
        let radii: [CLLocationDistance] = [150, 500]
        for radius in radii {
            if let found = await search(around: location, radius: radius) {
                return found
            }
        }
        return nil
    }

    private func search(around location: CLLocation, radius: CLLocationDistance) async -> LocatedPlace? {
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: radius)
        request.pointOfInterestFilter = .includingAll
        let search = MKLocalSearch(request: request)
        let response: MKLocalSearch.Response
        do {
            response = try await firstResponse(from: search)
        } catch {
            return nil
        }

        let ranked = response.mapItems.compactMap { item -> (MKMapItem, CLLocationDistance)? in
            let coordinate = coordinate(of: item)
            guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
            let name = item.name ?? item.placemark.name
            let hasName = !(name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            guard hasName || item.pointOfInterestCategory != nil else { return nil }
            let spot = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return (item, location.distance(from: spot))
        }
        .sorted { $0.1 < $1.1 }

        guard let nearest = ranked.first?.0 else { return nil }
        let raw = nearest.pointOfInterestCategory?.rawValue
        let reward = raw.map(POICategoryMapping.rewardCategory(forPOIRawValue:)) ?? .other
        return LocatedPlace(
            name: nearest.name ?? nearest.placemark.name,
            poiCategoryRaw: raw,
            rewardCategory: reward,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    private func firstResponse(from search: MKLocalSearch) async throws -> MKLocalSearch.Response {
        try await withThrowingTaskGroup(of: MKLocalSearch.Response.self) { group in
            group.addTask { @MainActor in
                try await search.start()
            }
            group.addTask { @MainActor in
                try await Task.sleep(for: .seconds(12))
                search.cancel()
                throw PlaceError.unavailable
            }
            guard let response = try await group.next() else {
                throw PlaceError.unavailable
            }
            group.cancelAll()
            return response
        }
    }

    private func coordinate(of item: MKMapItem) -> CLLocationCoordinate2D {
        item.placemark.coordinate
    }

    private func deadlineFired(token: Int) {
        guard token == generation else { return }
        generation += 1
        failPendingWaits()
        finishLocate(lookupAfterDeadline())
    }

    private func authorizationTimedOut(token: Int) {
        guard token == generation else { return }
        authorizationTimeout = nil
        let status = manager.authorizationStatus
        if authorizationContinuation != nil {
            finishAuthorization(status)
        }
    }

    private func locationTimedOut(token: Int) {
        guard token == generation else { return }
        locationTimeout = nil
        finishLocation(.failure(PlaceError.unavailable))
    }

    private func lookupAfterDeadline() -> PlaceLookup {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            return PlaceLookup(place: nil, problem: .denied)
        case .notDetermined:
            return PlaceLookup(place: nil, problem: .needsPermissionInApp)
        default:
            return PlaceLookup(place: nil, problem: .unavailable)
        }
    }

    private func finishLocate(_ value: PlaceLookup) {
        deadlineTask?.cancel()
        deadlineTask = nil
        guard let continuation = locateContinuation else { return }
        locateContinuation = nil
        continuation.resume(returning: value)
    }

    private func failPendingWaits() {
        authorizationTimeout?.cancel()
        authorizationTimeout = nil
        locationTimeout?.cancel()
        locationTimeout = nil
        if authorizationContinuation != nil {
            finishAuthorization(manager.authorizationStatus)
        }
        finishLocation(.failure(PlaceError.unavailable))
    }

    private func finishLocation(_ result: Result<CLLocation, Error>) {
        locationTimeout?.cancel()
        locationTimeout = nil
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(with: result)
    }

    private func finishAuthorization(_ status: CLAuthorizationStatus) {
        authorizationTimeout?.cancel()
        authorizationTimeout = nil
        guard let continuation = authorizationContinuation else { return }
        authorizationContinuation = nil
        continuation.resume(returning: status)
    }

    private func remember(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0 else { return }
        guard CLLocationCoordinate2DIsValid(location.coordinate) else { return }
        lastFix = location
        finishLocation(.success(location))
        onResolvedFix?(location)
    }

    private func problem(for error: PlaceError) -> LocationProblem {
        switch error {
        case .needsPermissionInApp: .needsPermissionInApp
        case .denied: .denied
        case .unavailable: .unavailable
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if status != .notDetermined {
                self.finishAuthorization(status)
            }
            self.onAuthorizationChange?(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.remember(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let code = (error as? CLError)?.code
        Task { @MainActor in
            if code == .locationUnknown {
                return
            }
            if code == .denied {
                self.finishLocation(.failure(PlaceError.denied))
                return
            }
            self.finishLocation(.failure(PlaceError.unavailable))
        }
    }
}
