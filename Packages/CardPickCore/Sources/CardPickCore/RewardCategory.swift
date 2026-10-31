import Foundation

/// Spend buckets the picker knows about. MapKit place types are translated
/// into one of these before any card rule runs.
public enum RewardCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case dining
    case gas
    case groceries
    case travel
    case drugstore
    case other

    public var displayName: String {
        switch self {
        case .dining: "Dining"
        case .gas: "Gas"
        case .groceries: "Groceries"
        case .travel: "Travel"
        case .drugstore: "Drugstore"
        case .other: "Other"
        }
    }
}
