//
//  UserDefaultsServiceProtocol.swift
//  Etalon2.0
//
//  Created by Artem Trubacheev on 23/08/2019.
//  Copyright © 2019 Tribuna Digital. All rights reserved.
//

/// @mockable
public protocol UserDefaultsServiceProtocol {
    func getValue<T>(forKey key: UserDefaultsKey<T>) -> T
    func setValue<T>(value: T, forKey key: UserDefaultsKey<T>)
    func register<T>(value: T, forKey key: UserDefaultsKey<T>)

    func removeAll()
}
