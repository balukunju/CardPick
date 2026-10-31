import Foundation
import CardPickCore

enum CategorySelection: Hashable {
    case detected
    case manual(RewardCategory)
}

enum CardAdvice {
    static func recommendation(
        catalog: CardCatalog,
        place: LocatedPlace?,
        selection: CategorySelection,
        valuation: PointValuation,
        allowFallback: Bool,
        on day: Day = .today()
    ) -> Recommendation? {
        guard let context = purchaseContext(
            place: place,
            selection: selection,
            on: day,
            allowFallback: allowFallback
        ) else {
            return nil
        }
        return BestCardPicker(catalog: catalog).recommend(context: context, valuation: valuation)
    }

    static func dialogLine(for recommendation: Recommendation, placeName: String?) -> String {
        let base = recommendation.spokenAnswer
        guard let placeName else { return base }
        let trimmed = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        if trimmed.compare(recommendation.placePhrase, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
            return base
        }
        return "\(base) (\(trimmed))"
    }

    private static func purchaseContext(
        place: LocatedPlace?,
        selection: CategorySelection,
        on day: Day,
        allowFallback: Bool
    ) -> PurchaseContext? {
        switch selection {
        case .manual(let category):
            // Spend stays nil: standing somewhere does not tell us the purchase
            // amount, so minimum-spend offers such as Peloton stay inactive.
            return PurchaseContext(
                category: category,
                merchant: nil,
                spend: nil,
                on: day,
                matchMerchants: false
            )
        case .detected:
            if let place {
                let named = place.hasPlaceIdentity
                return PurchaseContext(
                    category: place.rewardCategory,
                    merchant: named ? place.name : nil,
                    spend: nil,
                    on: day,
                    matchMerchants: named
                )
            }
            guard allowFallback else { return nil }
            return PurchaseContext(
                category: .other,
                merchant: nil,
                spend: nil,
                on: day,
                matchMerchants: false
            )
        }
    }
}

@MainActor
final class RecommendModel: ObservableObject {
    @Published private(set) var catalog: CardCatalog?
    @Published var loadError: String?
    @Published var place: LocatedPlace?
    @Published var selection: CategorySelection = .detected
    @Published var isLocating = false
    @Published var locationProblem: LocationProblem?

    private var requestID = 0

    init() {
        do {
            catalog = try CardCatalog.bundled()
        } catch {
            loadError = "The card list bundled with CardPick could not be read."
        }
        PlaceLocator.shared.onResolvedFix = { [weak self] _ in
            guard let self, !self.isLocating else { return }
            guard self.place == nil || self.locationProblem == .unavailable else { return }
            self.refresh()
        }
        PlaceLocator.shared.onAuthorizationChange = { [weak self] status in
            guard let self, !self.isLocating else { return }
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                if self.locationProblem == .denied || self.locationProblem == .needsPermissionInApp {
                    self.refresh()
                }
            case .denied, .restricted:
                self.locationProblem = .denied
            default:
                break
            }
        }
    }

    func refresh() {
        requestID += 1
        let currentRequest = requestID
        isLocating = true
        locationProblem = nil
        Task {
            let lookup = await PlaceLocator.shared.locate(promptIfNeeded: true)
            guard currentRequest == self.requestID else { return }
            if let found = lookup.place {
                place = found
            }
            locationProblem = lookup.problem
            isLocating = false
        }
    }

    func recommendation(valuation: PointValuation) -> Recommendation? {
        guard let catalog else { return nil }
        let manual: Bool
        if case .manual = selection {
            manual = true
        } else {
            manual = false
        }
        return CardAdvice.recommendation(
            catalog: catalog,
            place: place,
            selection: selection,
            valuation: valuation,
            allowFallback: manual || !isLocating
        )
    }
}
