import Foundation

public enum RewardType: String, Codable, Hashable, Sendable {
    /// Flat cash back. Wins ties against a points card with the same cents per dollar.
    case cashback
    case points
}

public enum Earn: Equatable, Sendable {
    case cashback(centsPerDollar: Decimal)
    case points(pointsPerDollar: Int)
}

extension Earn: Codable {
    private enum Kind: String, Codable {
        case cashback
        case points
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case centsPerDollar
        case pointsPerDollar
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .cashback:
            let cents = try container.decode(Decimal.self, forKey: .centsPerDollar)
            guard cents >= 0 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .centsPerDollar,
                    in: container,
                    debugDescription: "Cash back cannot be negative"
                )
            }
            self = .cashback(centsPerDollar: cents)
        case .points:
            let points = try container.decode(Int.self, forKey: .pointsPerDollar)
            guard points >= 0 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .pointsPerDollar,
                    in: container,
                    debugDescription: "Points per dollar cannot be negative"
                )
            }
            self = .points(pointsPerDollar: points)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .cashback(let cents):
            try container.encode(Kind.cashback, forKey: .kind)
            try container.encode(cents, forKey: .centsPerDollar)
        case .points(let points):
            try container.encode(Kind.points, forKey: .kind)
            try container.encode(points, forKey: .pointsPerDollar)
        }
    }
}

public struct CardRule: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let label: String
    /// Empty means this rule is not limited to a reward category.
    public let categories: [RewardCategory]
    /// Empty means this rule is not limited to a merchant. Matching is
    /// case-insensitive and ignores punctuation.
    public let merchants: [String]
    public let earn: Earn
    /// Inclusive last day the rule applies. Nil means the rule does not expire.
    public let expires: Day?
    /// Dollars. When set, the rule applies only if the purchase amount is known
    /// and at least this large. The place screen does not know the amount, so
    /// these offers stay inactive there.
    public let minimumSpend: Decimal?

    public init(
        id: String,
        label: String,
        categories: [RewardCategory] = [],
        merchants: [String] = [],
        earn: Earn,
        expires: Day? = nil,
        minimumSpend: Decimal? = nil
    ) {
        self.id = id
        self.label = label
        self.categories = categories
        self.merchants = merchants
        self.earn = earn
        self.expires = expires
        self.minimumSpend = minimumSpend
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case label
        case categories
        case merchants
        case earn
        case expires
        case minimumSpend
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        categories = try container.decodeIfPresent([RewardCategory].self, forKey: .categories) ?? []
        merchants = try container.decodeIfPresent([String].self, forKey: .merchants) ?? []
        earn = try container.decode(Earn.self, forKey: .earn)
        expires = try container.decodeIfPresent(Day.self, forKey: .expires)
        minimumSpend = try container.decodeIfPresent(Decimal.self, forKey: .minimumSpend)
        if let minimumSpend, minimumSpend < 0 {
            throw DecodingError.dataCorruptedError(
                forKey: .minimumSpend,
                in: container,
                debugDescription: "Minimum spend cannot be negative"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(categories, forKey: .categories)
        try container.encode(merchants, forKey: .merchants)
        try container.encode(earn, forKey: .earn)
        try container.encodeIfPresent(expires, forKey: .expires)
        try container.encodeIfPresent(minimumSpend, forKey: .minimumSpend)
    }

    public func centsPerDollar(valuingPointsAt valuation: PointValuation) -> Decimal {
        switch earn {
        case .cashback(let cents):
            return cents
        case .points(let points):
            return Decimal(points) * valuation.centsPerPoint
        }
    }
}

public struct Card: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let issuer: String
    public let rewardType: RewardType
    public let rules: [CardRule]

    public init(
        id: String,
        name: String,
        issuer: String,
        rewardType: RewardType,
        rules: [CardRule]
    ) {
        self.id = id
        self.name = name
        self.issuer = issuer
        self.rewardType = rewardType
        self.rules = rules
    }
}

/// How many cents one point is worth when a points card is compared with cash back.
/// Clamped to 1.0...2.0. The default is 1.5.
public struct PointValuation: Equatable, Sendable {
    public static let minimumCents = Decimal(1)
    public static let maximumCents = Decimal(2)
    public static let standard = PointValuation(centsPerPoint: Decimal(15) / Decimal(10))

    public let centsPerPoint: Decimal

    public init(centsPerPoint: Decimal) {
        if centsPerPoint < Self.minimumCents {
            self.centsPerPoint = Self.minimumCents
        } else if centsPerPoint > Self.maximumCents {
            self.centsPerPoint = Self.maximumCents
        } else {
            self.centsPerPoint = centsPerPoint
        }
    }

    /// Slider values are tenths of a cent. Doubles such as 1.1 are not exact,
    /// so this snaps to the nearest tenth before converting to `Decimal`.
    public init(sliderValue: Double) {
        let clamped = min(2, max(1, sliderValue))
        let tenths = Int((clamped * 10).rounded(.toNearestOrAwayFromZero))
        let bounded = min(20, max(10, tenths))
        self.init(centsPerPoint: Decimal(bounded) / Decimal(10))
    }

    public var displayText: String {
        "\(RateFormat.number(centsPerPoint))¢"
    }
}
