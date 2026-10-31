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
        do {
            let place = try await PlaceLocator.shared.locate(promptIfNeeded: false)
            guard let catalog = try? CardCatalog.bundled() else {
                return "CardPick couldn't read the card list."
            }
            guard let recommendation = CardAdvice.recommendation(
                catalog: catalog,
                place: place,
                selection: .detected,
                valuation: PointValueStore.storedValuation()
            ) else {
                return "CardPick has no cards to compare."
            }
            var line = CardAdvice.dialogLine(for: recommendation, placeName: place.name)
            if place.name == nil, place.poiCategoryRaw == nil {
                line += " No place name was found nearby."
            }
            return line
        } catch PlaceError.needsPermissionInApp {
            return "Open CardPick and allow location, then try again."
        } catch PlaceError.denied {
            return "Allow location access for CardPick in Settings, then try again."
        } catch {
            return "CardPick couldn't read your location. Open the app and try again."
        }
    }
}

struct CardPickShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .green

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
