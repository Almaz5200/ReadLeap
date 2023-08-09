import ComposableArchitecture
import SwiftUI

struct VoiceMemo: ReducerProtocol {
    struct State: Equatable, Identifiable {
        var mode = Mode.notPlaying
        var recording: Recording
        var id: String { self.recording.id }

        enum Mode: Equatable {
            case notPlaying
            case playing(progress: Double)

            var isPlaying: Bool {
                if case .playing = self { return true }
                return false
            }

            var progress: Double? {
                if case let .playing(progress) = self { return progress }
                return nil
            }
        }
    }

    enum Action: Equatable {
        case audioPlayerClient(TaskResult<Bool>)
        case delete
        case archive
        case playButtonTapped
        case timerUpdated(TimeInterval)
        case titleTextFieldChanged(String)
    }

    @Dependency(\.audioPlayer) var audioPlayer
    @Dependency(\.dataManager) var dataManager
    private enum PlayID {}

    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .audioPlayerClient:
            state.mode = .notPlaying
            return .cancel(id: PlayID.self)

        case .delete, .archive:
            return .cancel(id: PlayID.self)

        case .playButtonTapped:
            switch state.mode {
            case .notPlaying:
                state.mode = .playing(progress: 0)

                return .run { [audio = state.recording.audio] send in
                    guard let audio else { throw MyError() }
                    async let playAudio: Void = send(
                        .audioPlayerClient(TaskResult { try await self.audioPlayer.play(audio) })
                    )

                    await playAudio
                }
                .cancellable(id: PlayID.self, cancelInFlight: true)

            case .playing:
                state.mode = .notPlaying
                return .cancel(id: PlayID.self)
            }

        case let .timerUpdated(time):
            switch state.mode {
            case .notPlaying:
                break
            case .playing:
                state.mode = .playing(progress: time / state.recording.duration)
            }
            return .none

        case let .titleTextFieldChanged(text):
            state.recording.title = text
            return .run { [state] _ in await dataManager.saveRecording(recording: state.recording) }
        }
    }
}

struct VoiceMemoView: View {
    let store: StoreOf<VoiceMemo>

    var body: some View {
        WithViewStore(self.store) { viewStore in
            let currentTime =
                viewStore.mode.progress.map { $0 * viewStore.recording.duration } ?? viewStore.recording.duration
            HStack {
                if #available(iOS 16, *) {
                    TextField(
                        "Untitled, \(viewStore.recording.date.formatted(date: .numeric, time: .shortened))",
                        text: viewStore.binding(get: \.recording.title, send: { .titleTextFieldChanged($0) }), axis: .vertical
                    )
                    .submitLabel(.return)
                    .lineLimit(5)
                    .textInputAutocapitalization(.never)
                    .padding(.vertical, 4)
                } else {
                    ZStack {
                        Text(viewStore.recording.title)
                            .foregroundColor(.clear).padding(8)
                        TextEditor(
                            text: viewStore.binding(get: \.recording.title, send: { .titleTextFieldChanged($0) })
                        )
                        .textInputAutocapitalization(.never)
                    }
                }

                Spacer()

                Image(systemName: "clock")
                    .foregroundColor(Color(.systemGray))
                dateComponentsFormatter.string(from: currentTime).map {
                    Text($0)
                        .font(.footnote.monospacedDigit())
                        .foregroundColor(Color(.systemGray))
                        .padding(.trailing, 16)
                }

                Button(action: { viewStore.send(.playButtonTapped) }) {
                    Image(systemName: viewStore.mode.isPlaying ? "stop.circle" : "play.circle")
                        .font(.system(size: 26))
                }
            }
            .buttonStyle(.borderless)
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.horizontal)
            .listRowInsets(EdgeInsets())
            .background(
                Color(.systemGray5)
                    .frame(maxWidth: viewStore.mode.isPlaying ? .infinity : 0)
                    .animation(
                        viewStore.mode.isPlaying ? .linear(duration: viewStore.recording.duration) : nil,
                        value: viewStore.mode.isPlaying
                    ),
                alignment: .leading
            )
            .swipeActions(allowsFullSwipe: true) {
                if !viewStore.recording.title.isEmpty {
                    Button {
                        viewStore.send(.archive)
                    } label: {
                        Image(systemName: "archivebox")
                    }
                    .tint(.green)
                }

                Button {
                    viewStore.send(.delete)
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
            }
        }
        .enableInjection()
    }
}

struct MyError: Error {}
