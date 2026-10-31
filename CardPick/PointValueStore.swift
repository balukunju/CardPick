import Foundation
import CardPickCore

@MainActor
final class PointValueStore: ObservableObject {
    static let storageKey = "cardpick.points.centsPerPoint"

    @Published var centsPerPoint: Double {
        didSet {
            UserDefaults.standard.set(centsPerPoint, forKey: Self.storageKey)
        }
    }

    init() {
        let stored = UserDefaults.standard.object(forKey: Self.storageKey) as? Double ?? 1.5
        let clamped = min(2, max(1, stored))
        centsPerPoint = clamped
        if stored != clamped || UserDefaults.standard.object(forKey: Self.storageKey) == nil {
            UserDefaults.standard.set(clamped, forKey: Self.storageKey)
        }
    }

    var valuation: PointValuation {
        PointValuation(sliderValue: centsPerPoint)
    }

    nonisolated static func storedValuation() -> PointValuation {
        let stored = UserDefaults.standard.object(forKey: storageKey) as? Double ?? 1.5
        return PointValuation(sliderValue: stored)
    }
}
