import Foundation

/// Maps MapKit point-of-interest identifiers onto reward categories.
/// Accepts either a raw value such as `MKPOICategoryRestaurant` or the short
/// name `restaurant`.
public enum POICategoryMapping {
    public static func rewardCategory(forPOIRawValue rawValue: String) -> RewardCategory {
        kinds[normalize(rawValue)]?.reward ?? .other
    }

    public static func placeKindName(forPOIRawValue rawValue: String) -> String {
        if let name = kinds[normalize(rawValue)]?.name {
            return name
        }
        let stripped = stripPrefix(rawValue).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stripped.isEmpty else { return "Place" }
        return splitCamel(stripped)
    }

    private struct Kind {
        var reward: RewardCategory
        var name: String
    }

    private static let kinds: [String: Kind] = [
        "restaurant": Kind(reward: .dining, name: "Restaurant"),
        "cafe": Kind(reward: .dining, name: "Cafe"),
        "bakery": Kind(reward: .dining, name: "Bakery"),
        "brewery": Kind(reward: .dining, name: "Brewery"),
        "winery": Kind(reward: .dining, name: "Winery"),
        "nightlife": Kind(reward: .dining, name: "Nightlife"),
        "distillery": Kind(reward: .dining, name: "Distillery"),
        "foodmarket": Kind(reward: .groceries, name: "Grocery"),
        "gasstation": Kind(reward: .gas, name: "Gas Station"),
        "pharmacy": Kind(reward: .drugstore, name: "Pharmacy"),
        "hotel": Kind(reward: .travel, name: "Hotel"),
        "airport": Kind(reward: .travel, name: "Airport"),
        "store": Kind(reward: .other, name: "Store"),
        "carrental": Kind(reward: .other, name: "Car Rental"),
        "evcharger": Kind(reward: .other, name: "EV Charger"),
        "fitnesscenter": Kind(reward: .other, name: "Fitness Center"),
        "parking": Kind(reward: .other, name: "Parking"),
        "publictransport": Kind(reward: .other, name: "Public Transport")
    ]

    private static func normalize(_ rawValue: String) -> String {
        stripPrefix(rawValue).lowercased().filter(\.isLetter)
    }

    private static func stripPrefix(_ rawValue: String) -> String {
        let prefix = "MKPOICategory"
        if rawValue.hasPrefix(prefix) {
            return String(rawValue.dropFirst(prefix.count))
        }
        return rawValue
    }

    private static func splitCamel(_ raw: String) -> String {
        var spaced = ""
        for (index, character) in raw.enumerated() {
            if index > 0, character.isUppercase {
                spaced.append(" ")
            }
            spaced.append(character)
        }
        guard let first = spaced.first else { return "Place" }
        return first.uppercased() + spaced.dropFirst()
    }
}
