import SwiftUI

@main
struct CardPickApp: App {
    @StateObject private var points = PointValueStore()

    var body: some Scene {
        WindowGroup {
            RecommendView()
                .environmentObject(points)
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
        }
    }
}
