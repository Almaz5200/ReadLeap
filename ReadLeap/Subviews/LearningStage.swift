//
//  LearningStage.swift
//  VoiceMemos
//
//  Created by Artem Trubacheev on 25.01.2023.
//  Copyright © 2023 Point-Free. All rights reserved.
//

import ComposableArchitecture
import SwiftUI

struct LearningStage: ReducerProtocol {

    struct State: Equatable {
        var currentWordIndex = -1
        var fontSize = 14
        var words: IdentifiedArrayOf<Recording>
        var shouldCaps = false
        var shouldReplaceSpaces = false

        var currentWord: Recording {
            words[min(words.count - 1, max(0, currentWordIndex))]
        }

        var currentWordTitle: String {
            var word = currentWord.title
            if shouldCaps {
                word = word.uppercased()
            }

            if shouldReplaceSpaces {
                word = word.replacingOccurrences(of: " ", with: "\n")
            }

            return word
        }
    }

    enum Action {
        case nextWord
        case startLearning
        case finishedSpelling
        case didClickCancel
        case changeFontSize(Int)
        case setShouldCaps(Bool)
        case setShouldReplaceSpaces(Bool)
    }

    @Dependency(\.audioPlayer) var audioPlayer
    @Dependency(\.settingsProvider) var settingsProvider

    private enum PlayID {}

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .nextWord:
                state.currentWordIndex += 1
                return .run { [state] send in
                    if state.currentWordIndex == state.words.count {
                        await send(.finishedSpelling)
                    } else {
                        print(state.words)
                        if let audio = state.currentWord.audio {
                            _ = try await audioPlayer.play(audio)
                        }
                        await send(.nextWord)
                    }
                }
                .cancellable(id: PlayID.self, cancelInFlight: true)
            case .startLearning:
                state.currentWordIndex = -1
                Task { await setTimerEnabled(false) }
                return .run { send in
                    await send(.setShouldCaps(await settingsProvider.shouldUppercase))
                    await send(.setShouldReplaceSpaces(await settingsProvider.shouldReplaceSpacesWithNewlines))
                    await send(.changeFontSize(await settingsProvider.maxFontSize))
                    await send(.nextWord)
                }
            case .didClickCancel:
                return .cancel(id: PlayID.self)
            case .finishedSpelling:
                Task { await setTimerEnabled(true) }
                return .none
            case .changeFontSize(let fontSize):
                state.fontSize = fontSize
                return .none
            case .setShouldCaps(let should):
                state.shouldCaps = should
                return .none
            case .setShouldReplaceSpaces(let should):
                state.shouldReplaceSpaces = should
                return .none
            }
        }
    }

    @MainActor
    func setTimerEnabled(_ enabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = !enabled
    }
}

struct LearningStageView: View {
    let store: StoreOf<LearningStage>

    var body: some View {
        WithViewStore(self.store) { viewStore in
            ZStack {
                Text(viewStore.currentWordTitle)
                    .bold()
                    .font(.system(size: CGFloat(viewStore.fontSize)))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.red)
                    .minimumScaleFactor(0.01)
            }.onAppear {
                viewStore.send(.startLearning)
            }
            .onDisappear {
                viewStore.send(.didClickCancel)
            }
        }
        .enableInjection()
    }
}
