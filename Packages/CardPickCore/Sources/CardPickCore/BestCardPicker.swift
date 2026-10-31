import Foundation

public struct PurchaseContext: Equatable, Sendable {
    public var category: RewardCategory
    public var merchant: String?
    public var spend: Decimal?
    public var on: Day
    /// When false, merchant offers are skipped. The app does this for a manual
    /// category override, because that override means the detected place is wrong.
    public var matchMerchants: Bool

    public init(
        category: RewardCategory,
        merchant: String? = nil,
        spend: Decimal? = nil,
        on: Day,
        matchMerchants: Bool = true
    ) {
        self.category = category
        self.merchant = merchant
        self.spend = spend
        self.on = on
        self.matchMerchants = matchMerchants
    }
}

public struct CardEvaluation: Equatable, Sendable {
    public let card: Card
    public let rule: CardRule
    public let centsPerDollar: Decimal
    /// The merchant token that selected `rule`, when a merchant offer won.
    public let matchedMerchantName: String?

    public var shortRate: String {
        switch rule.earn {
        case .cashback(let cents):
            return "\(RateFormat.number(cents))% back"
        case .points(let points):
            return "\(points)x points"
        }
    }

    public var centsLabel: String {
        "\(RateFormat.number(centsPerDollar))¢ per $1"
    }
}

public struct Recommendation: Equatable, Sendable {
    public let winner: CardEvaluation
    public let runnerUp: CardEvaluation?
    public let context: PurchaseContext

    /// Merchant name when a merchant offer won, otherwise the reward category.
    public var placePhrase: String {
        winner.matchedMerchantName ?? context.category.displayName
    }

    public var spokenAnswer: String {
        "Use \(winner.card.name) — \(winner.shortRate) at \(placePhrase)"
    }

    public var comparisonNote: String? {
        guard let runnerUp else { return nil }
        if winner.centsPerDollar == runnerUp.centsPerDollar {
            if winner.card.rewardType == .cashback {
                return "Tied on earn rate. Cash back wins the tie."
            }
            return "Tied on earn rate."
        }
        let delta = winner.centsPerDollar - runnerUp.centsPerDollar
        return "\(RateFormat.number(delta))¢ per $1 more than \(runnerUp.card.name)"
    }
}

public struct BestCardPicker: Sendable {
    public let catalog: CardCatalog

    public init(catalog: CardCatalog) {
        self.catalog = catalog
    }

    /// Picks the card with the highest cents per dollar.
    ///
    /// For each card the best live rule wins, in this order: a matching
    /// merchant offer, then a matching category offer, then a catch-all
    /// (no merchant and no category). Expired rules are ignored. A rule with
    /// `minimumSpend` is ignored unless `context.spend` is at least that amount.
    /// Equal cents per dollar go to the cash-back card.
    public func recommend(context: PurchaseContext, valuation: PointValuation) -> Recommendation? {
        let ranked = catalog.cards.compactMap { card -> CardEvaluation? in
            guard let match = bestRule(for: card, context: context, valuation: valuation) else {
                return nil
            }
            return CardEvaluation(
                card: card,
                rule: match.rule,
                centsPerDollar: match.rule.centsPerDollar(valuingPointsAt: valuation),
                matchedMerchantName: match.merchant
            )
        }
        .sorted(by: comesBefore)

        guard let winner = ranked.first else { return nil }
        return Recommendation(winner: winner, runnerUp: ranked.dropFirst().first, context: context)
    }

    private func bestRule(
        for card: Card,
        context: PurchaseContext,
        valuation: PointValuation
    ) -> (rule: CardRule, merchant: String?)? {
        let eligible = card.rules.filter { isEligible($0, context: context) }

        let merchantHits: [(CardRule, String)] = eligible.compactMap { rule in
            guard context.matchMerchants, let place = context.merchant else { return nil }
            guard let token = rule.merchants.first(where: {
                MerchantMatching.matches(placeName: place, merchant: $0)
            }) else { return nil }
            if !rule.categories.isEmpty, !rule.categories.contains(context.category) {
                return nil
            }
            return (rule, token)
        }
        if let best = pickBest(merchantHits.map(\.0), valuation: valuation),
           let token = merchantHits.first(where: { $0.0.id == best.id })?.1 {
            return (best, token)
        }

        let categoryHits = eligible.filter {
            $0.merchants.isEmpty && $0.categories.contains(context.category)
        }
        if let best = pickBest(categoryHits, valuation: valuation) {
            return (best, nil)
        }

        let catchAll = eligible.filter { $0.merchants.isEmpty && $0.categories.isEmpty }
        if let best = pickBest(catchAll, valuation: valuation) {
            return (best, nil)
        }
        return nil
    }

    private func isEligible(_ rule: CardRule, context: PurchaseContext) -> Bool {
        if let expires = rule.expires, context.on > expires {
            return false
        }
        if let minimumSpend = rule.minimumSpend {
            guard let spend = context.spend, spend >= minimumSpend else { return false }
        }
        return true
    }

    private func pickBest(_ rules: [CardRule], valuation: PointValuation) -> CardRule? {
        rules.max { lhs, rhs in
            let left = lhs.centsPerDollar(valuingPointsAt: valuation)
            let right = rhs.centsPerDollar(valuingPointsAt: valuation)
            if left != right { return left < right }
            return lhs.id > rhs.id
        }
    }

    /// Strict ordering: higher cents first, then cash back, then card id.
    private func comesBefore(_ lhs: CardEvaluation, _ rhs: CardEvaluation) -> Bool {
        if lhs.centsPerDollar != rhs.centsPerDollar {
            return lhs.centsPerDollar > rhs.centsPerDollar
        }
        if lhs.card.rewardType != rhs.card.rewardType {
            return lhs.card.rewardType == .cashback
        }
        return lhs.card.id < rhs.card.id
    }
}
