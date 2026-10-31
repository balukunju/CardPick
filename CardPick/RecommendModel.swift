import Foundation
import CardPickCore

enum CategorySelection: Hashable {
    case detected
    case manual(RewardCategory)
}

enum LocationProblem: Equatable {
    case needsPermissionInApp
    case denied
    case unavailable
}

enum CardAdvice {
    static func recommendation(
        catalog: CardCatalog,
        place: LocatedPlace?,
        selection: CategorySelection,
        valuation: PointValuation,
        on day: Day = .today()
    ) -> Recommendation? {
        guard let context = purchaseContext(place: place, selection: selection, on: day) else {
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
        on day: Day
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
            guard let place else { return nil }
            return PurchaseContext(
                category: place.rewardCategory,
                merchant: place.name,
                spend: nil,
                on: day,
                matchMerchants: true
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
    }

    func refresh() {
        requestID += 1
        let currentRequest = requestID
        isLocating = true
        locationProblem = nil
        Task {
            do {
                let located = try await PlaceLocator.shared.locate(promptIfNeeded: true)
                guard currentRequest == self.requestID else { return }
                place = located
                locationProblem = nil
            } catch let error as PlaceError {
                guard currentRequest == self.requestID else { return }
                locationProblem = problem(for: error)
            } catch {
                guard currentRequest == self.requestID else { return }
                locationProblem = .unavailable
            }
            isLocating = false
        }
    }

    func recommendation(valuation: PointValuation) -> Recommendation? {
        guard let catalog else { return nil }
        return CardAdvice.recommendation(
            catalog: catalog,
            place: place,
            selection: selection,
            valuation: valuation
        )
    }

    private func problem(for error: PlaceError) -> LocationProblem {
        switch error {
        case .needsPermissionInApp: .needsPermissionInApp
        case .denied: .denied
        case .unavailable: .unavailable
        }
    }
}
