import Foundation

/// Модель данных атрибуции от AppsFlyer.
/// Сюда будем маппить сырые conversionData / deep link payload.
struct AppsFlyerAttributionModel {

    // MARK: - Основные поля

    /// Статус атрибуции:
    /// "Organic" / "Non-organic" / nil (если не пришло)
    let afStatus: String?

    /// Алиас кампании (наш {key})
    /// Откуда именно его брать (campaign, af_subX, custom param) — решим позже в парсере
    let key: String?

    /// Сабки, которые задаёт баер (sub1 … sub7)
    let sub1: String?
    let sub2: String?
    let sub3: String?
    let sub4: String?
    let sub5: String?
    let sub6: String?
    let sub7: String?

    /// AppsFlyer уникальный ID
    let appsflyerId: String?

    // MARK: - Доп. диагностика (опционально)

    /// Источник трафика (например, "facebook", "googleadwords_int", "tiktokglobal-int")
    let mediaSource: String?

    /// Название кампании (как есть в AppsFlyer)
    let campaign: String?

    /// Сырой словарь (для дебага, если понадобится)
    let rawData: [String: Any]

    // MARK: - Init

    /// Явный init, чтобы было понятно, что мы сюда кладём
    init(
        afStatus: String?,
        key: String?,
        sub1: String?,
        sub2: String?,
        sub3: String?,
        sub4: String?,
        sub5: String?,
        sub6: String?,
        sub7: String?,
        appsflyerId: String?,
        mediaSource: String?,
        campaign: String?,
        rawData: [String: Any]
    ) {
        self.afStatus = afStatus
        self.key = key
        self.sub1 = sub1
        self.sub2 = sub2
        self.sub3 = sub3
        self.sub4 = sub4
        self.sub5 = sub5
        self.sub6 = sub6
        self.sub7 = sub7
        self.appsflyerId = appsflyerId
        self.mediaSource = mediaSource
        self.campaign = campaign
        self.rawData = rawData

        print("📡 [AppsFlyerAttributionModel] Создана модель атрибуции")
        print("📡 [AppsFlyerAttributionModel] afStatus = \(afStatus ?? "nil")")
        print("📡 [AppsFlyerAttributionModel] key = \(key ?? "nil")")
        print("📡 [AppsFlyerAttributionModel] sub1..sub7 = [\(sub1 ?? "nil"), \(sub2 ?? "nil"), \(sub3 ?? "nil"), \(sub4 ?? "nil"), \(sub5 ?? "nil"), \(sub6 ?? "nil"), \(sub7 ?? "nil")]")
        print("📡 [AppsFlyerAttributionModel] appsflyerId = \(appsflyerId ?? "nil")")
        print("📡 [AppsFlyerAttributionModel] mediaSource = \(mediaSource ?? "nil"), campaign = \(campaign ?? "nil")")
    }
}
