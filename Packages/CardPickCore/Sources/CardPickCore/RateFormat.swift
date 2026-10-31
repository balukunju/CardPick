import Foundation

public enum RateFormat {
    /// Renders a rate with up to two decimal places and no trailing zeros.
    /// Avoids `NumberFormatter` so Linux and Apple platforms print the same text.
    public static func number(_ value: Decimal) -> String {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 2, .plain)

        let sign = rounded < 0 ? "-" : ""
        if rounded < 0 {
            rounded *= -1
        }

        var scaled = rounded * 100
        var scaledRounded = Decimal()
        NSDecimalRound(&scaledRounded, &scaled, 0, .plain)
        let cents = NSDecimalNumber(decimal: scaledRounded).int64Value
        let whole = cents / 100
        let fraction = abs(cents % 100)
        if fraction == 0 {
            return "\(sign)\(whole)"
        }
        if fraction < 10 {
            return "\(sign)\(whole).0\(fraction)"
        }
        if fraction.isMultiple(of: 10) {
            return "\(sign)\(whole).\(fraction / 10)"
        }
        return "\(sign)\(whole).\(fraction)"
    }
}
