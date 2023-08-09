import ComposableArchitecture
import SwiftUI

@main
struct ReadLeapApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            ReadLeapView(
                store: Store(
                    initialState: VoiceMemos.State(
                        settings: .init(colorScheme: .init(rawValue: UserDefaults.standard.integer(forKey: SettingsProviderImpl.colorSchemeKey)) ?? .unspecified)
                    ),
                    reducer: VoiceMemos()
                )
            )
            .tint(.purple)
        }
    }
}
