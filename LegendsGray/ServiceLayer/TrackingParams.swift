import Foundation

/// Общая структура со всеми параметрами, которые нужны
/// для построения финальной ссылки (URL → WebView)
///
/// Она будет собираться из:
/// 1. AppsFlyer (сабки, key, атрибуция)
/// 2. DeviceIdsProvider (idfa, idfv, app_id)
///
/// Эта структура пойдёт в LinkBuilder
///
struct TrackingParams {

    // MARK: - AppsFlyer (сабки + атрибуция)

    /// Алиас кампании (from AppsFlyer: "campaign", "{key}" или другое)
    let key: String?

    /// Сабки, которые задаёт баер (af_sub1 … af_sub7)
    let sub1: String?
    let sub2: String?
    let sub3: String?
    let sub4: String?
    let sub5: String?
    let sub6: String?
    let sub7: String?

    /// Атрибуция — organic / non-organic
    let afStatus: String?

    /// AppsFlyer уникальный ID
    let appsflyerId: String?

    // MARK: - Device (IDFA, IDFV, app_id)

    /// Advertising ID (может быть nil, если пользователь запретил tracking)
    let idfa: String?

    /// Identifier for Vendor (всегда доступен)
    let idfv: String?

    /// ID приложения (используем bundleIdentifier)
    let appId: String
}
