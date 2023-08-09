//
//  UserDefaultsKeys+List.swift
//
//
//  Created by Artem Trubacheev on 17.03.2022.
//

import CloudKit

extension UserDefaultsKeys {

    static let sharedDBChangeToken = UserDefaultsKey<CKServerChangeToken?>(key: "sharedDBChangeToken")
    static let didSubscribeToSharedDB = UserDefaultsKey<Bool>(defaultValue: false, key: "didSubscribeToSharedDB")

}

extension CKServerChangeToken: DefaultsSerializeable {

}
