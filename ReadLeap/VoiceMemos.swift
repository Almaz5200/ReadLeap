import AVFoundation
import Combine
import ComposableArchitecture
import CoreData
import Inject
import SwiftUI
import SwiftUIBackports

struct ArchiveElement: Hashable, Identifiable, Equatable, Codable {
    var id: String = UUID().uuidString
    var value: String
}

extension Array where Element: Equatable {
    var unique: [Element] {
        var uniqueValues: [Element] = []
        forEach { item in
            guard !uniqueValues.contains(item) else { return }
            uniqueValues.append(item)
        }
        return uniqueValues
    }
}

extension String {

    var localized: String {
        NSLocalizedString(self, bundle: .main, comment: "")
    }

    public func localizedPlural(arguments: CVarArg...) -> String {
        String(
            format: NSLocalizedString(localized, comment: ""),
            locale: .current,
            arguments: arguments
        )
    }

}

struct VoiceMemos: ReducerProtocol {
    struct State: Equatable {
        var alert: AlertState<Action>?
        var selectedGroup: Int?
        var audioRecorderPermission = RecorderPermission.undetermined
        var textRecognitionPermision = RecorderPermission.undetermined
        var recordingMemo: RecordingMemo.State?
        var allVoiceMemos: IdentifiedArrayOf<VoiceMemo.State> = []
        var voiceMemos: IdentifiedArrayOf<VoiceMemo.State> = []
        var isLearningActive: Bool = false
        var archive: [ArchiveElement] = []
        var settings: Settings.State = .init()

        enum RecorderPermission {
            case allowed
            case denied
            case undetermined
        }

        var archiveTitle: String {
            var result: String = ""
            result = "Архив".localizedPlural(arguments: archive.count)

            return result
        }
    }

    enum Action: Equatable {
        case subscribeToChanges
        case alertDismissed
        case openSettingsButtonTapped
        case recordButtonTapped
        case recordPermissionResponse(Bool)
        case voiceMemo(id: VoiceMemo.State.ID, action: VoiceMemo.Action)
        case clickLearnStage
        case updateMemos(IdentifiedArrayOf<VoiceMemo.State>)
        case refilterMemos
        case clearButtonTapped
        case didAppear
        case applyMove(IndexSet, Int)
        case selectGroup(Int?)
        case recordingMemo(RecordingMemo.Action)
        case settingsAction(Settings.Action)

        case addToArchive(String)
        case archiveAll
        case deleteFromArchive(Int)
        case moveInArchive(IndexSet, Int)
        case setArchive([ArchiveElement])
    }

    @Dependency(\.audioRecorder.requestRecordPermission) var requestRecordPermission
    @Dependency(\.date) var date
    @Dependency(\.openSettings) var openSettings
    @Dependency(\.storeDirectory) var storeDirectory
    @Dependency(\.uuid) var uuid
    @Dependency(\.settingsProvider) var settingsProvider
    @Dependency(\.dataManager) var dataManager
    var cancellables = Set<AnyCancellable>()

    func updatePublisher() -> AnyPublisher<Action, Never> {
        dataManager
            .currentDataPublisher
            .receive(on: DispatchQueue.main)
            .map { rec -> Action in
                let states =
                    rec
                    .map {
                        VoiceMemo.State(recording: $0)
                    }.unique
                return .updateMemos(IdentifiedArrayOf(uniqueElements: states))
            }.eraseToAnyPublisher()
    }

    func archivePublisher() -> AnyPublisher<Action, Never> {
        dataManager
            .archiveSubject
            .receive(on: DispatchQueue.main)
            .map { rec -> Action in
                return .setArchive(rec)
            }.eraseToAnyPublisher()
    }

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .setArchive(let result):
                state.archive = result
                return .none
            case .addToArchive(let string):
                var archive = state.archive
                archive.insert(.init(value: string), at: 0)
                return .run { [archive, dataManager] _ in
                    await dataManager.setArchive(archive: archive)
                }
            case .archiveAll:
                let archive = state.archive
                let newElements = state.voiceMemos.filter { !$0.recording.title.isEmpty }.map { ArchiveElement(value: $0.recording.title) }
                let voiceMemos = state.voiceMemos

                return .run { [archive, newElements, voiceMemos, dataManager] _ in
                    await dataManager.setArchive(archive: newElements + archive)
                    await voiceMemos.filter { !$0.recording.title.isEmpty }.asyncForEach {
                        await dataManager.removeRecording(recording: $0.recording)
                    }
                }

            case .settingsAction:
                return .none

            case .deleteFromArchive(let index):
                var archive = state.archive
                archive.remove(at: index)
                return .run { [archive, dataManager] _ in
                    await dataManager.setArchive(archive: archive)
                }

            case let .moveInArchive(indexSet, index):
                var archive = state.archive
                archive.move(fromOffsets: indexSet, toOffset: index)
                return .run { [archive] _ in
                    await dataManager.setArchive(archive: archive)
                }

            case .subscribeToChanges:
                return
                    .merge(
                        .publisher(updatePublisher),
                        .publisher(archivePublisher)
                    )
            case .alertDismissed:
                state.alert = nil
                return .none

            case .openSettingsButtonTapped:
                return .fireAndForget {
                    await self.openSettings()
                }

            case .recordButtonTapped:
                switch state.audioRecorderPermission {
                case .undetermined:
                    return .task {
                        await .recordPermissionResponse(self.requestRecordPermission())
                    }

                case .denied:
                    state.alert = AlertState {
                        TextState("Для записи голоса нужно разрешение.")
                    }
                    return .none

                case .allowed:
                    state.recordingMemo = newRecordingMemo
                    return .none
                }

            case let .recordingMemo(.delegate(.didFinish(.success(recordingMemo)))):
                state.recordingMemo = nil
                let audio = try? Data(contentsOf: recordingMemo.url)
                let recording = Recording(
                    date: recordingMemo.date,
                    duration: recordingMemo.duration,
                    title: recordingMemo.transctiption ?? "",
                    id: recordingMemo.id,
                    orderIndex: (state.allVoiceMemos.map { $0.recording.orderIndex }.max() ?? 0) + 1,
                    audio: audio,
                    group: state.selectedGroup
                )
                state.voiceMemos.append(VoiceMemo.State(recording: recording))
                return .run { send in
                    await dataManager.saveRecording(recording: recording)
                }

            case .recordingMemo(.delegate(.didFinish(.failure))):
                state.alert = AlertState {
                    TextState("Запись не удалась")
                }
                state.recordingMemo = nil
                return .none

            case .recordingMemo:
                return .none

            case let .recordPermissionResponse(permission):
                state.audioRecorderPermission = permission ? .allowed : .denied
                if permission {
                    state.recordingMemo = newRecordingMemo
                    return .none
                } else {
                    state.alert = AlertState {
                        TextState("Для записи голоса нужно разрешение.")
                    }
                    return .none
                }

            case .voiceMemo(id: _, action: .audioPlayerClient(.failure)):
                state.alert = AlertState {
                    TextState("Проигрывание не удалось")
                }
                return .none

            case let .voiceMemo(id: id, action: .delete):
                state.voiceMemos.remove(id: id)
                return .run { _ in
                    await dataManager.removeRecording(id: id)
                }

            case let .voiceMemo(id: id, action: .archive):
                let memo = state.voiceMemos[id: id]
                state.voiceMemos.remove(id: id)
                return .merge(
                    .run { _ in
                        await dataManager.removeRecording(id: id)
                    },
                    .send(.addToArchive(memo?.recording.title ?? ""))
                )

            case let .voiceMemo(id: tappedId, action: .playButtonTapped):
                for id in state.voiceMemos.ids where id != tappedId {
                    state.voiceMemos[id: id]?.mode = .notPlaying
                }
                return .none

            case .voiceMemo:
                return .none
            case .clickLearnStage:
                state.isLearningActive = true
                return .none
            case .didAppear:
                return .run(priority: .userInitiated) { send in
                    await send(.subscribeToChanges)
                 }
            case .clearButtonTapped:
                return .run(priority: .userInitiated) { send in
                    await dataManager.removeAll()
                }
            case .updateMemos(let memos):
                state.allVoiceMemos = memos
                return .send(.refilterMemos)
            case .refilterMemos:
                state.voiceMemos = state.allVoiceMemos.filter { $0.recording.group == state.selectedGroup || state.selectedGroup == nil }
                return .none
            case .applyMove(let source, let destination):
                state.voiceMemos.move(fromOffsets: source, toOffset: destination)
                var recordings = state.voiceMemos.map { $0.recording }
                let orderIndices = recordings.map { $0.orderIndex }.sorted()

                orderIndices.enumerated().forEach { recordings[$0].orderIndex = $1 }

                return .run { [recordings] send in
                    await dataManager.reorderedRecordings(
                        recordings: recordings
                    )
                }
            case .selectGroup(let group):
                state.selectedGroup = group
                print("selected group: \(group)")
                return .send(.refilterMemos)
            }
        }
        .ifLet(\.recordingMemo, action: /Action.recordingMemo) {
            RecordingMemo()
        }
        .forEach(\.voiceMemos, action: /Action.voiceMemo(id:action:)) {
            VoiceMemo()
        }

        Scope(state: \.settings, action: /Action.settingsAction) { Settings() }

    }

    private var newRecordingMemo: RecordingMemo.State {
        let id = self.uuid().uuidString
        return RecordingMemo.State(
            date: self.date.now,
            id: id,
            url: self.storeDirectory()
                .appendingPathComponent(id)
                .appendingPathExtension("m4a")
        )
    }
}

struct ReadLeapView: View {
    let store: StoreOf<VoiceMemos>
    @Namespace var anim

    @State var isExpanded = false

    @ObserveInjection var inj

    @ViewBuilder
    func groupPicker(_ tag: Int?, viewStore: ViewStore<VoiceMemos.State, VoiceMemos.Action>) -> some View {
        Button(tag == nil ? "Все слова".localized : "Группа".localizedPlural(arguments: tag!)) {
            viewStore.send(.selectGroup(tag))
        }
    }

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            NavigationView {
                VStack {
                    List {
                        Section {
                            GeometryReader { geo in
                                HStack {
                                    Menu {
                                        groupPicker(nil, viewStore: viewStore)
                                        ForEach(1..<10) { group in
                                            groupPicker(group, viewStore: viewStore)
                                        }
                                    } label: {
                                        HStack {
                                            Text(
                                                viewStore.state.selectedGroup == nil
                                                    ? "Все слова" : "Группа \(viewStore.state.selectedGroup!)")
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    }
                                    .frame(width: geo.size.width / 3)
                                    .padding(.trailing)

                                    Divider()

                                    Button("Архивировать группу") {
                                        viewStore.send(.archiveAll)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.accentColor)
                                    .frame(maxWidth: .infinity)
                                    .disabled(viewStore.state.voiceMemos.filter { !$0.recording.title.isEmpty }.isEmpty)
                                }
                            }
                        }

                        ForEachStore(
                            self.store.scope(state: \.voiceMemos, action: { .voiceMemo(id: $0, action: $1) })
                        ) {
                            if #available(iOS 16, *) {
                                VoiceMemoView(store: $0)
                                    .alignmentGuide(.listRowSeparatorLeading) { viewDimensions in
                                        16
                                    }
                            } else {
                                VoiceMemoView(store: $0)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewStore.send(.voiceMemo(id: viewStore.voiceMemos[index].id, action: .delete))
                            }
                        }
                        .onMove { a, b in
                            viewStore.send(.applyMove(a, b))
                        }

                        Section {
                            DisclosureGroup(isExpanded: $isExpanded) {
                                ForEach(viewStore.archive, id: \.self) {
                                    Text($0.value)
                                }
                                .onDelete { indexSet in
                                    for index in indexSet {
                                        viewStore.send(.deleteFromArchive(index))
                                    }
                                }
                                .onMove { a, b in
                                    viewStore.send(.moveInArchive(a, b))
                                }
                            } label: {
                                HStack {
                                    Text("Архив")
                                    HStack(spacing: 0) {
                                        Group {
                                            let generalCount = viewStore.archive.count
                                            let uniqueCount = Set(viewStore.archive.map { $0.value }).count
                                            Text("\(generalCount)")

                                            if uniqueCount != viewStore.archive.count {
                                                Text("/")
                                                Text("\(uniqueCount)")
                                            }
                                        }
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background {
                                        RoundedRectangle(cornerRadius: 100)
                                            .fill(Color.accentColor)
                                    }

                                }
                            }
                        }
                    }
                    .animation(.default, value: viewStore.archive)
                    .animation(.default, value: viewStore.voiceMemos)
                    .animation(.default, value: isExpanded)

                    Section {
                        IfLetStore(
                            self.store.scope(state: \.recordingMemo, action: { .recordingMemo($0) })
                        ) { store in
                            RecordingMemoView(store: store)
                        } else: {
                            RecordButton(permission: viewStore.audioRecorderPermission) {
                                viewStore.send(.recordButtonTapped, animation: .spring())
                            } settingsAction: {
                                viewStore.send(.openSettingsButtonTapped)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                }
                .backport.scrollDismissesKeyboard(.interactively)
                .alert(
                    self.store.scope(state: \.alert),
                    dismiss: .alertDismissed
                )
                .navigationTitle("Слова")
                .onAppear { viewStore.send(.didAppear) }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        NavigationLink {
                            SettingsView(
                                store: self.store.scope(state: \.settings, action: { act in .settingsAction(act) })
                            )
                        } label: {
                            Image(systemName: "gear")
                        }
                        .accessibility(label: Text("Настройки"))
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            EditButton()
                            NavigationLink {
                                LearningStageView(
                                    store: Store(
                                        initialState: LearningStage.State(
                                            words: IdentifiedArrayOf(
                                                uniqueElements: viewStore.voiceMemos.filter {
                                                    !$0.recording.title.isEmpty
                                                }
                                                .map {
                                                    $0.recording
                                                }
                                                .unique
                                            )), reducer: LearningStage()))
                            } label: {
                                Image(systemName: "play.fill")
                            }
                            .disabled(
                                viewStore.voiceMemos.filter {
                                    !$0.recording.title.isEmpty
                                }
                                .isEmpty
                            )
                        }
                    }
                }
            }
            .navigationViewStyle(.stack)
            .preferredColorScheme(viewStore.settings.colorScheme.asColorScheme)
        }
        .enableInjection()
    }
}

struct RecordButton: View {
    let permission: VoiceMemos.State.RecorderPermission
    let action: () -> Void
    let settingsAction: () -> Void

    var body: some View {
        ZStack {
            Group {
                Circle()
                    .foregroundColor(Color(.label))
                    .frame(width: 74, height: 74)

                Button(action: self.action) {
                    RoundedRectangle(cornerRadius: 35)
                        .foregroundColor(Color(.systemRed))
                        .padding(2)
                }
                .frame(width: 70, height: 70)
            }
            .opacity(self.permission == .denied ? 0.1 : 1)

            if self.permission == .denied {
                VStack(spacing: 10) {
                    Text("Запись голоса требует разрешения.")
                        .multilineTextAlignment(.center)
                    Button("Разрешить", action: self.settingsAction)
                }
                .frame(maxWidth: .infinity, maxHeight: 74)
            }
        }
    }
}
