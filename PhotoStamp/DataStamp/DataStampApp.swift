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

// MARK: - App delegate to handle window close → quit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true  // Quit when the main window is closed
    }
}

// MARK: - App entry point

@main
struct ImageStampApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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

        Settings {
            SettingsView()
                .environment(\.dynamicTypeSize, scaledDynamicTypeSize)
                .environment(\.uiScale, settings.uiScale)
                .preferredColorScheme(settings.appearanceMode.colorScheme)
                .frame(minWidth: 500, minHeight: 560)
        }
        .windowResizability(.contentSize)
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
