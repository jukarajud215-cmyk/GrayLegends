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

/// Реализация провайдера девайс-идентификаторов.
/// Здесь же добавлены принты для отладки.
final class DeviceIdsProvider: DeviceIdsProviding {

    // MARK: - Public

    /// IDFA (Advertising Identifier)
    /// Если пользователь запретил трекинг → вернётся nil
    var idfa: String? {
        let manager = ASIdentifierManager.shared()
        let uuid = manager.advertisingIdentifier

        // Если tracking отключён или ATT denied, часто приходит all-zero UUID
        let uuidString = uuid.uuidString
        let isZeroId = uuidString == "00000000-0000-0000-0000-000000000000"

        if manager.isAdvertisingTrackingEnabled == false || isZeroId {
            print("📱 [DeviceIdsProvider] IDFA недоступен (tracking disabled или zero UUID)")
            return nil
        }

        print("📱 [DeviceIdsProvider] IDFA = \(uuidString)")
        return uuidString
    }

    /// IDFV (Identifier for Vendor)
    var idfv: String? {
        let value = UIDevice.current.identifierForVendor?.uuidString

        if let value {
            print("📱 [DeviceIdsProvider] IDFV = \(value)")
        } else {
            print("📱 [DeviceIdsProvider] IDFV недоступен")
        }

        return value
    }

    /// app_id — используем bundle identifier как идентификатор приложения
    /// (если заказчик захочет другой формат — потом поменяем здесь)
    var appId: String {
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown_app_id"
        print("📱 [DeviceIdsProvider] appId (bundleIdentifier) = \(bundleId)")
        return bundleId
    }

    // MARK: - Init

    init() {
        print("📱 [DeviceIdsProvider] Инициализирован")
    }
}
