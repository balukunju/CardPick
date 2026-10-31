import AppIntents
import CardPickCore

struct WhichCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Which card here?"
    static var description = IntentDescription("Recommends which of your cards earns the most at the place you're at.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let line = await LivePick.spokenLine()
        return .result(value: line, dialog: IntentDialog(stringLiteral: line))
    }
}

@MainActor
private enum LivePick {
    static func spokenLine() async -> String {
        let lookup = await PlaceLocator.shared.locate(promptIfNeeded: false)
        switch lookup.problem {
        case .denied, .needsPermissionInApp where lookup.place == nil:
            return "Location permission denied. Allow location for CardPick in Settings, then try again."
        case .unavailable where lookup.place == nil:
            return "Couldn't get your location. Open CardPick and try again."
        default:
            break
        }
        guard let catalog = try? CardCatalog.bundled() else {
            return "CardPick couldn't read the card list."
        }
        guard let recommendation = CardAdvice.recommendation(
            catalog: catalog,
            place: lookup.place,
            selection: .detected,
            valuation: PointValueStore.storedValuation(),
            allowFallback: true
        ) else {
            return "CardPick has no cards to compare."
        }
        var line = CardAdvice.dialogLine(for: recommendation, placeName: lookup.place?.name)
        if lookup.problem == .noPlace || lookup.place?.hasPlaceIdentity != true {
            line += " No place found nearby."
        }
        return line
    }
}

struct CardPickShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .teal

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WhichCardIntent(),
            phrases: [
                "Which card here with \(.applicationName)",
                "Which card should I use with \(.applicationName)",
                "Best card here with \(.applicationName)"
            ],
            shortTitle: "Which card here?",
            systemImageName: "creditcard.fill"
        )
    }
}
