//
// Created by Artem Trubacheev on 01.05.2023.
// Copyright (c) 2023 Point-Free. All rights reserved.
//

import CloudKit
import CoreData
import FirebaseCore
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {

    static var PersistentContainer: NSPersistentCloudKitContainer!

    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "Model")
        let remoteChangeKey = "NSPersistentStoreRemoteChangeNotificationOptionKey"

        let defaultDesctiption = container.persistentStoreDescriptions.first
        let url = defaultDesctiption?.url?.deletingLastPathComponent()
        let privateDescription = NSPersistentStoreDescription(url: url!.appendingPathComponent("private.sqlite"))
        let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.socialKidApp")
        privateOptions.databaseScope = .private
        privateDescription.cloudKitContainerOptions = privateOptions
        privateDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        privateDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.persistentStoreDescriptions = [privateDescription]

        container.loadPersistentStores(completionHandler: {
            (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true

        return container
    }()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppDelegate.PersistentContainer = persistentContainer
        //        FirebaseApp.configure()

        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) async -> UIBackgroundFetchResult {
        print(userInfo)

        return .noData
    }

}
