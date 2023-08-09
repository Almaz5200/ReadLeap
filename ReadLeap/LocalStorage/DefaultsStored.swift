//
// Created by Artem Trubacheev on 01.07.2022.
//

import Foundation

@propertyWrapper
public struct DefaultsStored<T: DefaultsSerializeable, Service: UserDefaultsServiceProtocol> {

    let key: UserDefaultsKey<T>
    let defaults: UserDefaultsServiceProtocol

    public var wrappedValue: T {
        get { defaults.getValue(forKey: key) }
        set { defaults.setValue(value: newValue, forKey: key) }
    }

    public init(_ key: UserDefaultsKey<T>, defaults: Service) {
        self.key = key
        self.defaults = defaults
    }

    public init(_ key: UserDefaultsKey<T>) where Service == UserDefaultsService {
        self.key = key
        defaults = UserDefaultsService.shared
    }

}
