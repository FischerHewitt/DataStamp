import SwiftUI

@main
struct DataStampApp: App {

    @ObservedObject private var settings = SettingsStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Scale the entire UI — affects font sizes and SF Symbol sizes
                .environment(\.dynamicTypeSize, scaledDynamicTypeSize)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }

    /// Map our 0.8–1.4 slider to the nearest DynamicTypeSize step.
    private var scaledDynamicTypeSize: DynamicTypeSize {
        switch settings.uiScale {
        case ..<0.85: return .xSmall
        case ..<0.95: return .small
        case ..<1.05: return .medium        // default
        case ..<1.15: return .large
        case ..<1.25: return .xLarge
        case ..<1.35: return .xxLarge
        default:      return .xxxLarge
        }
    }
}
