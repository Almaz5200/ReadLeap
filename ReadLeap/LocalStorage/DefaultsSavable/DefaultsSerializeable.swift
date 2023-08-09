//
//  DefaultsSerializeable.swift
//  Etalon2.0
//
//  Created by Artem Trubacheev on 23/08/2019.
//  Copyright © 2019 Tribuna Digital. All rights reserved.
//

import Foundation

public protocol DefaultsSerializeable {
    associatedtype RealType = Self

    static func register(key: String, value: Self, userDefaults: UserDefaults?)
    static func save(key: String, value: Self, userDefaults: UserDefaults?)
    static func get(key: String, userDefaults: UserDefaults?) -> RealType?
}

extension DefaultsSerializeable {

    public static func register(key: String, value: Self, userDefaults: UserDefaults?) {
        userDefaults?.register(defaults: [key: value])
    }

    public static func save(key: String, value: Self, userDefaults: UserDefaults?) {
        userDefaults?.set(value, forKey: key)
    }

    public static func get(key: String, userDefaults: UserDefaults?) -> Self? {
        userDefaults?.value(forKey: key) as? Self
    }

}

extension String: DefaultsSerializeable {}
extension Int: DefaultsSerializeable {}
extension Date: DefaultsSerializeable {}
extension Double: DefaultsSerializeable {}
extension Bool: DefaultsSerializeable {
    public static func get(key: String, userDefaults: UserDefaults?) -> Bool? {
        guard userDefaults?.value(forKey: key) != nil else { return nil }
        return userDefaults?.bool(forKey: key)
    }
}
extension Dictionary: DefaultsSerializeable where Key: DefaultsSerializeable, Value: DefaultsSerializeable {}
extension Array: DefaultsSerializeable where Element: Codable {

    public static func register(key: String, value: RealType, userDefaults: UserDefaults?) {
        let data = try? JSONEncoder().encode(value)
        userDefaults?.register(defaults: [key: data as Any])
    }

    public static func save(key: String, value: RealType, userDefaults: UserDefaults?) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        userDefaults?.set(data, forKey: key)
    }

    public static func get(key: String, userDefaults: UserDefaults?) -> [Element]? {
        guard let data = userDefaults?.data(forKey: key) else { return nil }

        return try? JSONDecoder().decode(self, from: data)
    }

}

extension Optional: DefaultsSerializeable where Wrapped: DefaultsSerializeable {

    public typealias RealType = Wrapped

    public static func register(key: String, value: RealType?, userDefaults: UserDefaults?) {
        guard let value = value else { return }
        Wrapped.register(key: key, value: value, userDefaults: userDefaults)
    }

    public static func save(key: String, value: RealType?, userDefaults: UserDefaults?) {
        if let value = value {
            RealType.save(key: key, value: value, userDefaults: userDefaults)
        } else {
            userDefaults?.set(nil, forKey: key)
        }
    }

    public static func get(key: String, userDefaults: UserDefaults?) -> RealType? {
        Wrapped.get(key: key, userDefaults: userDefaults) as? RealType
    }

}
