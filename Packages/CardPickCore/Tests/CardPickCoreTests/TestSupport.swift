import Foundation

/// `Decimal.init(string:)` is not available in swift-corelibs-foundation.
func decimal(_ string: String) -> Decimal {
    let negative = string.hasPrefix("-")
    let body = negative ? String(string.dropFirst()) : string
    let parts = body.split(separator: ".", omittingEmptySubsequences: false)
    let whole = Decimal(Int(parts[0]) ?? 0)
    guard parts.count > 1, let fractionPart = parts.last else {
        return negative ? -whole : whole
    }
    let digits = String(fractionPart)
    let fraction = Decimal(Int(digits) ?? 0)
    var scale = Decimal(1)
    for _ in digits {
        scale *= 10
    }
    let value = whole + fraction / scale
    return negative ? -value : value
}
