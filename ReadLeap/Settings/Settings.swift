//
//  SettingsView.swift
//  VoiceMemos
//
//  Created by Artem Trubacheev on 29.04.2023.
//  Copyright © 2023 Point-Free. All rights reserved.
//

import ComposableArchitecture
import Inject
import SwiftUI

struct Settings: ReducerProtocol {

    struct State: Equatable {
        var maxFontSize: Int = 300
        var colorScheme: AppColorScheme = .unspecified
        var shouldUppercase: Bool = false
        var shouldReplaceSpacesWithNewlines: Bool = false
    }

    enum Action: Equatable {
        case didAppear
        case didChangeFontUp
        case didChangeFontDown
        case setFontSize(Int)
        case setColorScheme(AppColorScheme)
        case setShouldUppercase(Bool)
        case setShouldReplaceSpacesWithNewlines(Bool)
    }

    @Dependency(\.settingsProvider) var settingsProvider

    private enum PlayID {}

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .didAppear:
                return .run { send in
                    let colorScheme = await settingsProvider.colorScheme
                    await send(.setColorScheme(colorScheme))
                    let maxFontSize = await settingsProvider.maxFontSize
                    await send(.setFontSize(maxFontSize))
                    let shouldUppercase = await settingsProvider.shouldUppercase
                    await send(.setShouldUppercase(shouldUppercase))
                    let shouldReplaceSpacesWithNewlines = await settingsProvider.shouldReplaceSpacesWithNewlines
                    await send(.setShouldReplaceSpacesWithNewlines(shouldReplaceSpacesWithNewlines))

                }
            case .didChangeFontUp:
                let newFontSize = state.maxFontSize + 1
                state.maxFontSize = newFontSize
                return .run { [newFontSize] send in
                    await settingsProvider.setMaxFontSize(newFontSize)
                }
            case .didChangeFontDown:
                let newFontSize = state.maxFontSize - 1
                state.maxFontSize = newFontSize
                return .run { [newFontSize] send in
                    await settingsProvider.setMaxFontSize(newFontSize)
                }
            case let .setFontSize(maxFontSize):
                state.maxFontSize = maxFontSize
                return .run { send in
                    await settingsProvider.setMaxFontSize(maxFontSize)
                }
            case let .setColorScheme(colorScheme):
                state.colorScheme = colorScheme
                return .run { send in
                    await settingsProvider.setColorScheme(colorScheme)
                }
            case let .setShouldUppercase(shouldUppercase):
                state.shouldUppercase = shouldUppercase
                return .run { send in
                    await settingsProvider.setShouldUppercase(shouldUppercase)
                }
            case let .setShouldReplaceSpacesWithNewlines(shouldReplaceSpacesWithNewlines):
                state.shouldReplaceSpacesWithNewlines = shouldReplaceSpacesWithNewlines
                return .run { send in
                    await settingsProvider.setShouldReplaceSpacesWithNewlines(shouldReplaceSpacesWithNewlines)
                }
            }
        }
    }

    @MainActor
    func setTimerEnabled(_ enabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = !enabled
    }
}

struct SettingsView: View {
    let store: StoreOf<Settings>

    @ObserveInjection var inj

    var body: some View {
        WithViewStore(self.store) { viewStore in
            List {
                Section {
                    VStack(alignment: .leading) {
                        Text("Тема")
                        Picker("Палитра", selection: viewStore.binding(get: \.colorScheme, send: Settings.Action.setColorScheme)) {
                            Text("Светлая").tag(AppColorScheme.light)
                            Text("Авто").tag(AppColorScheme.unspecified)
                            Text("Темная").tag(AppColorScheme.dark)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle(
                        "Большие буквы",
                        isOn: viewStore.binding(get: \.shouldUppercase, send: Settings.Action.setShouldUppercase)
                    )
                    Toggle(
                        "Переносить слова",
                        isOn: viewStore.binding(
                            get: \.shouldReplaceSpacesWithNewlines,
                            send: Settings.Action.setShouldReplaceSpacesWithNewlines
                        )
                    )
                }
                Section {
                    HStack {
                        Text("Максимальный шрифт")
                        Spacer()
                        // Number picker with
                        Picker("Максимальный шрифт", selection: viewStore.binding(get: \.maxFontSize, send: Settings.Action.setFontSize)) {
                            ForEach(1..<500) { i in
                                Text("\(i)")
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                }
            }
            .listRowSeparator(.hidden)
            .onAppear { viewStore.send(.didAppear) }
        }
        .enableInjection()
    }
}
