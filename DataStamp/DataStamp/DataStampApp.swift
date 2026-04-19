import SwiftUI

// MARK: - Custom environment key for UI scale

private struct UIScaleKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

extension EnvironmentValues {
    var uiScale: Double {
        get { self[UIScaleKey.self] }
        set { self[UIScaleKey.self] = newValue }
    }
}

// MARK: - App entry point

@main
struct DataStampApp: App {

    @ObservedObject private var settings = SettingsStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.dynamicTypeSize, scaledDynamicTypeSize)
                .environment(\.uiScale, settings.uiScale)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }

    private var scaledDynamicTypeSize: DynamicTypeSize {
        switch settings.uiScale {
        case ..<0.85: return .xSmall
        case ..<0.95: return .small
        case ..<1.05: return .medium
        case ..<1.15: return .large
        case ..<1.25: return .xLarge
        case ..<1.35: return .xxLarge
        default:      return .xxxLarge
        }
    }
}
