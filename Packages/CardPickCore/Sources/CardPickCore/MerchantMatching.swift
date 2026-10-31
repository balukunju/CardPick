import Foundation

public enum MerchantMatching {
    /// True when `placeName` contains `merchant` as a whole name or phrase.
    /// "Lyft" matches "Lyft" and "Lyft Hub", and does not match "Flyft".
    public static func matches(placeName: String, merchant: String) -> Bool {
        let place = canonical(placeName)
        let needle = canonical(merchant)
        guard !place.isEmpty, !needle.isEmpty else { return false }

        var start = place.startIndex
        while let range = place.range(of: needle, range: start..<place.endIndex) {
            if hasBoundary(place, around: range) {
                return true
            }
            start = place.index(after: range.lowerBound)
        }
        return false
    }

    private static func hasBoundary(_ place: String, around range: Range<String.Index>) -> Bool {
        let beforeOK: Bool
        if range.lowerBound == place.startIndex {
            beforeOK = true
        } else {
            let before = place[place.index(before: range.lowerBound)]
            beforeOK = !before.isLetter && !before.isNumber
        }
        let afterOK: Bool
        if range.upperBound == place.endIndex {
            afterOK = true
        } else {
            let after = place[range.upperBound]
            afterOK = !after.isLetter && !after.isNumber
        }
        return beforeOK && afterOK
    }

    private static func canonical(_ string: String) -> String {
        let folded = string.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        let spaced = String(folded.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        })
        return spaced.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
