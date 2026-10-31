import SwiftUI
import UIKit
import CardPickCore

struct RecommendView: View {
    @EnvironmentObject private var points: PointValueStore
    @Environment(\.openURL) private var openURL
    @StateObject private var model = RecommendModel()
    @ScaledMetric(relativeTo: .largeTitle) private var answerSize: CGFloat = 40

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let loadError = model.loadError {
                            infoCard(title: "Cards unavailable", message: loadError)
                        } else {
                            content
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("CardPick")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
        .task {
            if model.place == nil, !model.isLocating {
                model.refresh()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        statusBanner
        if let recommendation = model.recommendation(valuation: points.valuation) {
            answerCard(recommendation)
            if let runnerUp = recommendation.runnerUp {
                runnerCard(runnerUp, note: recommendation.comparisonNote)
            }
        } else if model.isLocating {
            locatingCard
        }
        if let place = model.place, place.hasPlaceIdentity {
            placeCard(place)
        }
        categoryPicker
        refreshButton
        Text("CardPick recommends a card. iOS keeps the Apple Pay default under your control.")
            .font(.footnote)
            .foregroundStyle(Palette.secondaryText)
        Text("Action Button shortcut: Which card here?")
            .font(.footnote)
            .foregroundStyle(Palette.secondaryText)
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch model.locationProblem {
        case .denied, .needsPermissionInApp:
            infoCard(
                title: "Location permission denied",
                message: "Allow location while using CardPick, or pick a category. \(fallbackNote)"
            )
            settingsButton
        case .unavailable:
            infoCard(
                title: "Couldn't get your location",
                message: model.place?.hasPlaceIdentity == true
                    ? "Showing the last place CardPick found. \(fallbackNote)"
                    : "On the Simulator, choose Features → Location and pick a city, then tap Retry. \(fallbackNote)"
            )
        case .noPlace:
            infoCard(
                title: "No place found nearby",
                message: "Pick a category if this guess is wrong. \(fallbackNote)"
            )
        case nil:
            EmptyView()
        }
    }

    private var settingsButton: some View {
        Button("Open Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .foregroundStyle(Palette.accent)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.accent, lineWidth: 1)
        }
        .accessibilityLabel("Open Settings")
    }

    private var fallbackNote: String {
        if case .manual(let category) = model.selection {
            return "The recommendation uses \(category.displayName)."
        }
        return "The recommendation uses Other."
    }

    private var locatingCard: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(Palette.accent)
            Text("Finding the nearest place")
                .font(.headline)
                .foregroundStyle(Palette.primaryText)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func answerCard(_ recommendation: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Use")
                .font(.caption.weight(.semibold))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Palette.secondaryText)
            Text(recommendation.winner.card.name)
                .font(.system(size: answerSize, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.primaryText)
                .minimumScaleFactor(0.55)
                .lineLimit(2)
            Text(recommendation.winner.shortRate)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Palette.accent)
            Text(recommendation.winner.centsLabel)
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
            Text("at \(recommendation.placePhrase)")
                .font(.title3.weight(.medium))
                .foregroundStyle(Palette.primaryText)
                .padding(.top, 4)
            Text(recommendation.winner.rule.label)
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Palette.accent.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func runnerCard(_ runnerUp: CardEvaluation, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Runner-up")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.secondaryText)
            Text(runnerUp.card.name)
                .font(.headline)
                .foregroundStyle(Palette.primaryText)
            Text("\(runnerUp.shortRate) · \(runnerUp.centsLabel)")
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func placeCard(_ place: LocatedPlace) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.isLocating ? "Refreshing place" : "Nearest place")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.secondaryText)
            Text(place.name ?? "No named place nearby")
                .font(.headline)
                .foregroundStyle(Palette.primaryText)
            Text(placeDetail(place))
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Category")
                    .font(.headline)
                    .foregroundStyle(Palette.primaryText)
                Spacer()
                Picker("Category", selection: $model.selection) {
                    Text(detectedMenuTitle).tag(CategorySelection.detected)
                    ForEach(RewardCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(CategorySelection.manual(category))
                    }
                }
                .pickerStyle(.menu)
                .tint(Palette.accent)
            }
            Text("Use this when the place lookup picked the wrong category.")
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
        }
        .padding(18)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var refreshButton: some View {
        Button {
            model.refresh()
        } label: {
            if model.isLocating {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Palette.accentInk)
                    Text("Finding place…")
                }
            } else if model.locationProblem != nil {
                Text("Retry")
            } else {
                Text("Refresh")
            }
        }
        .buttonStyle(FillButtonStyle())
        .disabled(model.isLocating)
        .accessibilityLabel(model.locationProblem == nil ? "Refresh location" : "Retry location")
    }

    private var detectedMenuTitle: String {
        if let place = model.place, place.hasPlaceIdentity {
            return "Detected · \(place.rewardCategory.displayName)"
        }
        if !model.isLocating {
            return "Detected · Other"
        }
        return "Detected"
    }

    private func placeDetail(_ place: LocatedPlace) -> String {
        let kind = place.kindName
        let reward = place.rewardCategory.displayName
        if let kind, kind.caseInsensitiveCompare(reward) != .orderedSame {
            return "\(kind) · \(reward)"
        }
        return reward
    }

    private func infoCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.primaryText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct FillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Palette.accent.opacity(configuration.isPressed ? 0.75 : 1))
            .foregroundStyle(Palette.accentInk)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
