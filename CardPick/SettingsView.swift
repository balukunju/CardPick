import SwiftUI
import CardPickCore

struct SettingsView: View {
    @EnvironmentObject private var points: PointValueStore

    private let catalog: CardCatalog?

    init() {
        catalog = try? CardCatalog.bundled()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                pointValueCard
                cardsCard
                Text("Cards are read from the bundled cards.json file. Edit that file in the repo and rebuild to change a rate, a merchant, or an end date. The point value above stays on this iPhone.")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
            }
            .padding(20)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var pointValueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Point value")
                .font(.headline)
                .foregroundStyle(Palette.primaryText)
            Text(points.valuation.displayText)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.accent)
                .accessibilityLabel("\(points.valuation.displayText) per point")
            Slider(value: $points.centsPerPoint, in: 1...2, step: 0.1)
                .tint(Palette.accent)
                .accessibilityLabel("Cents per point")
            HStack {
                Text("1.0¢")
                Spacer()
                Text("2.0¢")
            }
            .font(.caption)
            .foregroundStyle(Palette.secondaryText)
            Text("Points cards are compared with cash back at this many cents per point. Chase Sapphire Reserve uses 1.5¢ unless you change it.")
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var cardsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your cards")
                .font(.headline)
                .foregroundStyle(Palette.primaryText)
            if let catalog {
                ForEach(catalog.cards) { card in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(card.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Palette.primaryText)
                        Text(card.issuer)
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondaryText)
                        ForEach(card.rules) { rule in
                            Text(rule.label)
                                .font(.subheadline)
                                .foregroundStyle(Palette.primaryText)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.top, 4)
                }
            } else {
                Text("The card list could not be read.")
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
