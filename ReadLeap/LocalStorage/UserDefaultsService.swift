//
//  UserDefaultsService.swift
//  Etalon2.0
//
//  Created by Artem Trubacheev on 23/08/2019.
//  Copyright © 2019 Tribuna Digital. All rights reserved.
//

import UIKit

public class UserDefaultsService: UserDefaultsServiceProtocol {

    private var defaults: UserDefaults { UserDefaults.standard }

    
    public static let shared = UserDefaultsService()
    fileprivate init() {}

    public func getValue<T>(forKey key: UserDefaultsKey<T>) -> T {
        let value: T.RealType? = T.get(key: key.rawKey, userDefaults: defaults)

        return value == nil
            ? key.defaultValue
            : value as? T ?? key.defaultValue
    }

    public func setValue<T>(value: T, forKey key: UserDefaultsKey<T>) {
        T.save(key: key.rawKey, value: value, userDefaults: defaults)
    }

    public func register<T>(value: T, forKey key: UserDefaultsKey<T>) {
        T.register(key: key.rawKey, value: value, userDefaults: defaults)
    }

    public func removeAll() {
        defaults.dictionaryRepresentation().keys.forEach {
            defaults.removeObject(forKey: $0)
        }
    }

}
