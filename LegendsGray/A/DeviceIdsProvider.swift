import Foundation
import AdSupport
import UIKit

/// Протокол для получения девайс-идентификаторов.
/// Через него потом будем дергать idfa/idfv/appId
protocol DeviceIdsProviding {
    /// Advertising ID (может быть nil, если трекинг запрещён)
    var idfa: String? { get }

    /// Identifier for Vendor (обычно всегда доступен)
    var idfv: String? { get }

    /// ID приложения (используем bundle identifier)
    var appId: String { get }
}


final class DeviceIdsProvider: DeviceIdsProviding {

    // MARK: - Public

    var idfa: String? {
        let manager = ASIdentifierManager.shared()
        let uuid = manager.advertisingIdentifier
        let uuidString = uuid.uuidString
        
        // Проверка на нули и выключенный трекинг
        if manager.isAdvertisingTrackingEnabled == false || uuidString == "00000000-0000-0000-0000-000000000000" {
            print("📱 [DeviceIdsProvider] IDFA недоступен или скрыт")
            return nil
        }
        print("📱 [DeviceIdsProvider] IDFA = \(uuidString)")
        return uuidString
    }

    var idfv: String? {
        let value = UIDevice.current.identifierForVendor?.uuidString
        print("📱 [DeviceIdsProvider] IDFV = \(value ?? "nil")")
        return value
    }

    /// Возвращаем числовой ID из конфига
    var appId: String {
        let id = AppConfig.appleAppID
        print("📱 [DeviceIdsProvider] appId (numeric) = \(id)")
        return id
    }

    init() {
        print("📱 [DeviceIdsProvider] Инициализирован")
    }
}
