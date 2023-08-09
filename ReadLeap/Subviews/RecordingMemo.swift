import ComposableArchitecture
import SwiftUI

struct RecordingMemo: ReducerProtocol {
    struct State: Equatable {
        var date: Date
        var duration: TimeInterval = 0
        var transctiption: String?
        var mode: Mode = .recording
        var id: String
        var url: URL

        enum Mode {
            case recording
            case encoding
        }
    }

    enum Action: Equatable {
        case audioRecorderDidFinish(TaskResult<Bool>)
        case delegate(DelegateAction)
        case finalRecordingTime(TimeInterval)
        case setTransctiption(String?)
        case task
        case timerUpdated
        case startTimer
        case stopButtonTapped
    }

    enum DelegateAction: Equatable {
        case didFinish(TaskResult<State>)
    }

    struct Failed: Equatable, Error {}

    @Dependency(\.audioRecorder) var audioRecorder
    @Dependency(\.mainQueue) var mainQueue
    private struct TimerID: Hashable {}

    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .audioRecorderDidFinish(.success(true)):
            return .task { [state] in .delegate(.didFinish(.success(state))) }

        case .audioRecorderDidFinish(.success(false)):
            return .task { .delegate(.didFinish(.failure(Failed()))) }

        case let .audioRecorderDidFinish(.failure(error)):
            return .task { .delegate(.didFinish(.failure(error))) }

        case .delegate:
            return .none

        case let .finalRecordingTime(duration):
            state.duration = duration
            return .none

        case .stopButtonTapped:
            state.mode = .encoding
            return .merge([
                .cancel(id: TimerID()),
                .run { send in
                    if let currentTime = await self.audioRecorder.currentTime() {
                        await send(.finalRecordingTime(currentTime))
                    }
                    await send(.setTransctiption(await self.audioRecorder.stopRecording()))
                },
            ])

        case .setTransctiption(let transcription):
            state.transctiption = transcription
            return .none

        case .startTimer:
            return EffectTask.timer(id: TimerID(), every: 1, tolerance: nil, on: mainQueue)
                .map { _ in .timerUpdated }

        case .task:
            return .run { [url = state.url] send in
                async let startRecording: Void = send(
                    .audioRecorderDidFinish(
                        TaskResult { try await self.audioRecorder.startRecording(url) }
                    )
                )
                await send(.startTimer)
                await startRecording
            }

        case .timerUpdated:
            state.duration += 1
            return .none
        }

    }
}

struct RecordingMemoView: View {
    let store: StoreOf<RecordingMemo>

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack(spacing: 12) {
                Text("Запись")
                    .font(.title)
                    .colorMultiply(Color(Int(viewStore.duration).isMultiple(of: 2) ? .systemRed : .label))
                    .animation(.easeInOut(duration: 0.5), value: viewStore.duration)

                if let formattedDuration = dateComponentsFormatter.string(from: viewStore.duration) {
                    Text(formattedDuration)
                        .font(.body.monospacedDigit().bold())
                        .foregroundColor(.black)
                }

                ZStack {
                    Circle()
                        .foregroundColor(Color(.label))
                        .frame(width: 74, height: 74)

                    Button(action: { viewStore.send(.stopButtonTapped, animation: .default) }) {
                        RoundedRectangle(cornerRadius: 4)
                            .foregroundColor(Color(.systemRed))
                            .padding(17)
                    }
                    .frame(width: 70, height: 70)
                }
            }
            .task {
                await viewStore.send(.task).finish()
            }
        }
    }
}
