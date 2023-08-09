//
// Created by Artem Trubacheev on 29.04.2023.
// Copyright (c) 2023 Point-Free. All rights reserved.
//

import Combine
import SwiftUI

enum AppColorScheme: Int, Sendable, CaseIterable, Identifiable {
    case unspecified
    case light
    case dark

    var id: Int { rawValue }

    var asColorScheme: ColorScheme? {
        switch self {
        case .unspecified:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

protocol SettingsProvider: Actor {
    var maxFontSize: Int { get }
    var colorScheme: AppColorScheme { get }
    var shouldUppercase: Bool { get }
    var shouldReplaceSpacesWithNewlines: Bool { get }

    func setMaxFontSize(_ maxFontSize: Int)
    func setColorScheme(_ colorScheme: AppColorScheme)
    func setShouldUppercase(_ shouldUppercase: Bool)
    func setShouldReplaceSpacesWithNewlines(_ shouldReplaceSpacesWithNewlines: Bool)

    func updatesAsyncStream() -> AsyncStream<Void>
}

actor SettingsProviderImpl: Sendable, SettingsProvider {
    var maxFontSize: Int = 14
    private let maxFontSizeKey = "maxFontSize"

    var colorScheme: AppColorScheme
     static let colorSchemeKey = "colorScheme"

    var shouldUppercase: Bool
    private let shouldUppercaseKey = "shouldUppercase"

    var shouldReplaceSpacesWithNewlines: Bool
    private let shouldReplaceSpacesWithNewlinesKey = "shouldReplaceSpacesWithNewlines"

    let defaults = UserDefaults.standard
    static let shared = SettingsProviderImpl()

    var updates: AnyPublisher<Void, Never> {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .map { _ in }
            .eraseToAnyPublisher()
    }

    init() {
        let maxFontSize = defaults.value(forKey: maxFontSizeKey) as? Int
        self.maxFontSize = maxFontSize ?? 300
        self.colorScheme = AppColorScheme(rawValue: defaults.integer(forKey: SettingsProviderImpl.colorSchemeKey)) ?? .unspecified

        self.shouldUppercase = (defaults.value(forKey: shouldUppercaseKey) as? Bool) ?? true
        self.shouldReplaceSpacesWithNewlines = (defaults.value(forKey: shouldReplaceSpacesWithNewlinesKey) as? Bool) ?? true
    }

    func setMaxFontSize(_ maxFontSize: Int) {
        self.maxFontSize = maxFontSize
        defaults.setValue(maxFontSize, forKey: maxFontSizeKey)
    }

    func setColorScheme(_ colorScheme: AppColorScheme) {
        self.colorScheme = colorScheme
        defaults.setValue(colorScheme.rawValue, forKey: SettingsProviderImpl.colorSchemeKey)
    }

    func setShouldUppercase(_ shouldUppercase: Bool) {
        self.shouldUppercase = shouldUppercase
        defaults.setValue(shouldUppercase, forKey: shouldUppercaseKey)
    }

    func setShouldReplaceSpacesWithNewlines(_ shouldReplaceSpacesWithNewlines: Bool) {
        self.shouldReplaceSpacesWithNewlines = shouldReplaceSpacesWithNewlines
        defaults.setValue(shouldReplaceSpacesWithNewlines, forKey: shouldReplaceSpacesWithNewlinesKey)
    }

    func updatesAsyncStream() -> AsyncStream<Void> {
        return AsyncStream<Void> { continuation in
            let observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: nil) { _ in
                continuation.yield(())
            }
        }
    }

}
