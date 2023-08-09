//
//  UserDefaultsKeys.swift
//  Etalon2.0
//
//  Created by Bogdan Kostyuchenko on 11/12/2018.
//  Copyright © 2018 Tribuna Digital. All rights reserved.
//

import Foundation

public class UserDefaultsKeys {}

public class UserDefaultsKey<ValueType: DefaultsSerializeable>: UserDefaultsKeys {

    public var rawKey: String
    public let defaultValue: ValueType

    public init(defaultValue: ValueType, key: String) {
        self.defaultValue = defaultValue
        rawKey = key
    }

}

extension UserDefaultsKey where ValueType: NilableType {

    public convenience init(_ defaultValue: ValueType = .empty, key: String) {
        self.init(defaultValue: defaultValue, key: key)
    }

}

extension UserDefaultsKey: Equatable {

    public static func ==<T>(lhs: UserDefaultsKey<T>, rhs: UserDefaultsKey<T>) -> Bool { lhs.rawKey == rhs.rawKey }

}
