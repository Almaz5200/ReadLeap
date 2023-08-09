import Foundation

/// This class just saves value without touching UserDefaults
/// So that the data is lost after app restart
public class UserDefaultsLocalService: UserDefaultsServiceProtocol {

    var storage: [String: Any] = [:]

    public static let shared = UserDefaultsLocalService()
    private init() { }

    public func getValue<T>(forKey key: UserDefaultsKey<T>) -> T {
        guard let value = storage[key.rawKey] as? T else {
            return key.defaultValue
        }
        return value
    }

    public func setValue<T>(value: T, forKey key: UserDefaultsKey<T>) {
        storage[key.rawKey] = value
    }

    public func register<T>(value: T, forKey key: UserDefaultsKey<T>) {
        storage[key.rawKey] = value
    }

    public func removeAll() {
        storage.removeAll()
    }

}
