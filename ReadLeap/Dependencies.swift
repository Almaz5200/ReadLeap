import Dependencies
import SwiftUI
import XCTestDynamicOverlay

extension DependencyValues {
    var openSettings: @Sendable () async -> Void {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }

    private enum OpenSettingsKey: DependencyKey {
        typealias Value = @Sendable () async -> Void

        static let liveValue: @Sendable () async -> Void = {
            await MainActor.run {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
        }
        static let testValue: @Sendable () async -> Void = unimplemented(
            #"@Dependency(\.openSettings)"#
        )
    }

    var temporaryDirectory: @Sendable () -> URL {
        get { self[TemporaryDirectoryKey.self] }
        set { self[TemporaryDirectoryKey.self] = newValue }
    }

    private enum TemporaryDirectoryKey: DependencyKey {
        static let liveValue: @Sendable () -> URL = { URL(fileURLWithPath: NSTemporaryDirectory()) }
        static let testValue: @Sendable () -> URL = XCTUnimplemented(
            #"@Dependency(\.temporaryDirectory)"#,
            placeholder: URL(fileURLWithPath: NSTemporaryDirectory())
        )
    }

    var storeDirectory: @Sendable () -> URL {
        get { self[StoreDirectoryKey.self] }
        set { self[StoreDirectoryKey.self] = newValue }
    }

    private enum StoreDirectoryKey: DependencyKey {
        static let liveValue: @Sendable () -> URL = {
            let attempted = try? FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let fallback = URL(fileURLWithPath: NSTemporaryDirectory())
            return attempted ?? fallback
        }
    }

    var dataManager: DataManager {
        get { self[DataManagerKey.self] }
        set { self[DataManagerKey.self] = newValue }
    }

    private enum DataManagerKey: DependencyKey {
        static let liveValue: DataManager = DataManager.shared
    }

    var settingsProvider: any SettingsProvider {
        get { self[SettingsProviderKey.self] }
        set { self[SettingsProviderKey.self] = newValue }
    }

    private enum SettingsProviderKey: DependencyKey {
        static let liveValue: any SettingsProvider = SettingsProviderImpl.shared
    }

}
