//
//  DataManager.swift
//  VoiceMemos
//
//  Created by Artem Trubacheev on 25.01.2023.
//  Copyright © 2023 Point-Free. All rights reserved.
//

import CloudKit
import Combine
import ComposableArchitecture
import CoreData
import Foundation
import OSLog
import UIKit

actor BackgroundCoredataLayer {

    var context: NSManagedObjectContext

    init(container: NSPersistentCloudKitContainer) {
        context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    }

}

@MainActor
final class DataManager: Sendable {
    var currentData: [Recording] {
        didSet {
            currentDataSubject.send(currentData)
        }
    }
    let currentDataSubject = CurrentValueSubject<[Recording], Never>([])
    let archiveSubject = CurrentValueSubject<[ArchiveElement], Never>([])

    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()

    let currentDataPublisher: AnyPublisher<[Recording], Never>
    var currentNSManagedObjectData: [RecordingModel] = []

    var logger = Logger(subsystem: "DataManager", category: "DataManager")

    let archiveKey = "archive"
    let storageKey = "recordings"
    @MainActor
    lazy var persistentContainer: NSPersistentCloudKitContainer = AppDelegate.PersistentContainer

    let userDefaults = UserDefaultsService.shared
    var cancellable: AnyCancellable?

    static let shared = DataManager()

    private init() {
        currentData = []

        currentDataPublisher = currentDataSubject.eraseToAnyPublisher()
        subscribeToChanges()
        makeArchive()
        updateData()
    }

    func getSubject() -> AnyPublisher<[Recording], Never> {
        currentDataSubject
            .eraseToAnyPublisher()
    }

    func makeArchive() {
        NSUbiquitousKeyValueStore.default.synchronize()
        let data = NSUbiquitousKeyValueStore.default.object(forKey: archiveKey) as? [Data] ?? []
        let archive = data.compactMap { try? jsonDecoder.decode(ArchiveElement.self, from: $0) }
        archiveSubject.send(archive)
    }

    @MainActor
    func subscribeToChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateData(notification:)),
            name: .NSPersistentStoreRemoteChange,
            object: persistentContainer.persistentStoreCoordinator
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateArchive(notification:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil
        )
    }

    @objc
    nonisolated func updateData(notification: Notification) {
        Task {
            await updateData()
        }
    }

    @objc
    nonisolated func updateArchive(notification: Notification) {
        NSUbiquitousKeyValueStore.default.synchronize()
        Task { @MainActor in
            makeArchive()
        }
    }

    func setArchive(archive: [ArchiveElement]) {
        let data = archive.compactMap { try? jsonEncoder.encode($0) }
        NSUbiquitousKeyValueStore.default.set(data, forKey: archiveKey)
        Task { @MainActor in
            archiveSubject.send(archive)
        }
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func getRecordings() async -> [Recording] {
        var set = Set<Recording>()
        let fetchedRecordings = currentData
        var uniqueRecordings = [Recording]()

        for recording in fetchedRecordings {
            if !set.contains(recording) {
                set.insert(recording)
                uniqueRecordings.append(recording)
            }
        }

        return uniqueRecordings
    }

    func updateData() {
        Task { @MainActor in
            fetchPersistedData {
                switch $0 {
                case .success(let recordings):
                    self.setCurrentManagedObjectsData(recordings)
                case .failure(let error):
                    print("Sad filin' :(")
                }
            }
        }
    }

    func setCurrentManagedObjectsData(_ data: [RecordingModel]) {
        currentNSManagedObjectData = data
        currentData = data.map(Map.modelToRecording).sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    func fetchPersistedData(_ callback: @escaping (Result<[RecordingModel], Error>) -> Void) {
        let fetchRequest = RecordingModel.fetchRequest()
        let viewContext = persistentContainer.viewContext
        try? viewContext.setQueryGenerationFrom(.current)

        do {
            let allItems = try viewContext.fetch(fetchRequest)
            callback(.success(allItems))
        } catch {
            callback(.failure(error))
        }
    }

    func removeRecording(recording: Recording) {
        removeRecording(id: recording.id)
    }

    func removeRecording(id: String) {
        guard let managedObject = currentNSManagedObjectData.first(where: { $0.id == id })
        else { return }
        persistentContainer.viewContext.delete(managedObject)

        currentData.removeAll(where: { $0.id == id })

        saveChangesToContext()
    }

    func saveRecording(recording: Recording, saveToContext: Bool = true) {
        let model = currentNSManagedObjectData.first(where: { $0.id == recording.id }) ?? createNewRecordingModel()
        Map.recordingToModel(recording: recording, model: model)

        if let id = currentData.firstIndex(where: { $0.id == recording.id }) {
            currentData[id] = recording
        } else {
            currentData.append(recording)
        }

        if saveToContext {
            saveChangesToContext()
        }
    }

    private func createNewRecordingModel() -> RecordingModel {
        return RecordingModel(context: persistentContainer.viewContext)
    }

    private func saveChangesToContext() {
        let viewContext = persistentContainer.viewContext
        if viewContext.hasChanges {
            do {
                try viewContext.save()
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    func removeAll() async {
        currentData.forEach {
            removeRecording(recording: $0)
        }
    }

    func reorderedRecordings(recordings: [Recording]) async {
        await recordings.asyncForEach {
            await saveRecording(recording: $0)
        }
        await saveChangesToContext()
    }

}

enum Map {

    static func modelToRecording(model: RecordingModel) -> Recording {
        let group = Int(model.group)
        return Recording(
            date: model.date ?? Date(),
            duration: model.duration,
            title: model.title ?? "",
            id: model.id ?? UUID().uuidString,
            orderIndex: Int(model.orderIndex),
            audio: model.audio,
            group: group == -1 ? nil : group
        )
    }

    static func recordingToModel(recording: Recording, model: RecordingModel) {
        model.date = recording.date
        model.duration = recording.duration
        model.id = recording.id
        model.title = recording.title
        model.orderIndex = Int64(recording.orderIndex)
        model.audio = recording.audio
        model.group = Int64(recording.group ?? -1)
    }

}

struct Recording: Codable, Equatable, Identifiable, Hashable {
    var date: Date
    var duration: TimeInterval
    var title = ""
    var id: String
    var orderIndex: Int
    var audio: Data?
    var group: Int?
}

extension Sequence {
    func asyncForEach(
        _ operation: (Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await operation(element)
        }
    }
}
