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


import Foundation
import AdSupport
import AppTrackingTransparency
import UIKit

final class DeviceIdsProvider: DeviceIdsProviding {

    // MARK: - Public

    var idfa: String? {
        // 1. Сначала проверяем статус разрешения (iOS 14+)
        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            
            switch status {
            case .authorized:
                print("📱 [DeviceIdsProvider] ATT статус: Authorized")
            case .denied:
                print("📱 [DeviceIdsProvider] ATT статус: Denied")
                return nil
            case .notDetermined:
                print("📱 [DeviceIdsProvider] ATT статус: Not Determined (еще не спросили)")
                return nil
            case .restricted:
                print("📱 [DeviceIdsProvider] ATT статус: Restricted")
                return nil
            @unknown default:
                return nil
            }
        }

        // 2. Получаем сам ID
        let uuid = ASIdentifierManager.shared().advertisingIdentifier
        let uuidString = uuid.uuidString

        // 3. Проверка на нули (Apple отдает нули, если трекинг запрещен)
        if uuidString == "00000000-0000-0000-0000-000000000000" {
            print("📱 [DeviceIdsProvider] IDFA равен нулям (система скрыла ID)")
            return nil
        }

        print("📱 [DeviceIdsProvider] IDFA получен: \(uuidString)")
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
        print("📱 [DeviceIdsProvider] appId = \(id)")
        return id
    }

    init() {
        print("📱 [DeviceIdsProvider] Инициализирован")
    }
}
