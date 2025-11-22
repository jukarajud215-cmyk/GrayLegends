import Foundation
import AppsFlyerLib

/// Протокол сервиса атрибуции AppsFlyer.
/// Через него остальные части приложения будут получать данные по трафику.
protocol AppsFlyerAttributionServicing {

    /// Последняя известная атрибуция (если уже что-то прилетало)
    var currentAttribution: AppsFlyerAttributionModel? { get }

    /// Подписка на атрибуцию.
    /// Коллбек вызовется, когда:
    ///  - придут conversionData
    ///  - или deep link с атрибуцией
    func observeAttribution(_ observer: @escaping (AppsFlyerAttributionModel) -> Void)

    /// Обработка conversion data из AppsFlyer (вызывается из AppDelegate)
    func handleConversionData(_ data: [AnyHashable: Any])

    /// Обработка deep link результата (вызывается из AppDelegate)
    func handleDeepLink(result: DeepLinkResult)
}

/// Реализация сервиса атрибуции AppsFlyer.
/// Здесь мы:
///  - принимаем сырые данные из SDK
///  - парсим их в AppsFlyerAttributionModel
///  - кэшируем
///  - оповещаем всех подписчиков
final class AppsFlyerAttributionService: AppsFlyerAttributionServicing {
    
    // MARK: - Singleton (для простоты)
    
    /// Общий инстанс сервиса (можно потом заменить на DI, если понадобится)
    static let shared = AppsFlyerAttributionService()
    
    // MARK: - Public
    
    /// Последняя известная атрибуция
    private(set) var currentAttribution: AppsFlyerAttributionModel? {
        didSet {
            if let model = currentAttribution {
                notifyObservers(with: model)
            }
        }
    }
    
    // MARK: - Private
    
    /// Список подписчиков на атрибуцию
    private var observers: [(AppsFlyerAttributionModel) -> Void] = []
    
    // MARK: - Init
    
    private init() {
        print("📡 [AppsFlyerAttributionService] Инициализирован")
    }
    
    // MARK: - Observation
    
    func observeAttribution(_ observer: @escaping (AppsFlyerAttributionModel) -> Void) {
        print("📡 [AppsFlyerAttributionService] Добавлен новый observer атрибуции")
        observers.append(observer)
        
        // Если атрибуция уже есть — сразу отдадим её наблюдателю
        if let model = currentAttribution {
            print("📡 [AppsFlyerAttributionService] Сразу отдаём уже имеющуюся атрибуцию observer'у")
            observer(model)
        }
    }
    
//    private func notifyObservers(with model: AppsFlyerAttributionModel) {
//        print("📡 [AppsFlyerAttributionService] Оповещение \(observers.count) observers об атрибуции")
//        observers.forEach { $0(model) }
//    }
    
    private func notifyObservers(with model: AppsFlyerAttributionModel) {
            print("📡 [AppsFlyerAttributionService] Оповещение \(observers.count) observers об атрибуции")
            
            // 🚨 ВАЖНЫЙ ФИКС:
            // AppsFlyer работает в фоне, а UI (RootVC) нужно обновлять в Main потоке.
            // Оборачиваем уведомление в main.async:
            DispatchQueue.main.async {
                self.observers.forEach { $0(model) }
            }
        }
    
    // MARK: - Conversion Data
    
    /// Обработка conversion data (первичная атрибуция установки)
    func handleConversionData(_ data: [AnyHashable: Any]) {
        print("📡 [AppsFlyerAttributionService] handleConversionData вызван")
        print("📡 [AppsFlyerAttributionService] Raw conversion data: \(data)")
        
        // Приводим ключи к [String: Any]
        let normalized = normalize(dictionary: data)
        
        // Парсим в модель
        let model = parseAttribution(from: normalized, source: "conversion_data")
        
        currentAttribution = model
    }
    
    // MARK: - Deep Link
    
    /// Обработка результата диплинка
    func handleDeepLink(result: DeepLinkResult) {
        print("📡 [AppsFlyerAttributionService] handleDeepLink вызван")
        print("📡 [AppsFlyerAttributionService] DeepLinkResult status: \(result.status)")
        print("📡 [AppsFlyerAttributionService] DeepLinkResult error: \(String(describing: result.error))")
        
        guard let deepLink = result.deepLink else {
            print("📡 [AppsFlyerAttributionService] DeepLinkResult.deepLink = nil, атрибуции нет")
            return
        }
        
        let data = deepLink.clickEvent
        print("📡 [AppsFlyerAttributionService] DeepLink clickEvent: \(data)")
        
        let model = parseAttribution(from: data, source: "deep_link")
        currentAttribution = model
    }
    
    func handleLegacyDeepLink(_ data: [AnyHashable: Any]) {
          print("📡 [AppsFlyerAttributionService] handleLegacyDeepLink вызван")
          
          // Нормализуем словарь (AnyHashable -> String)
          let normalized = normalize(dictionary: data)
          
          // Парсим используя ту же логику, что и везде
          let model = parseAttribution(from: normalized, source: "legacy_deeplink")
          
          // Обновляем текущую атрибуцию (это триггернет RootViewController)
          currentAttribution = model
      }
    
    // MARK: - Parsing
    
    /// Нормализация словаря AnyHashable → String
    private func normalize(dictionary: [AnyHashable: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        dictionary.forEach { key, value in
            if let keyString = key as? String {
                result[keyString] = value
            } else {
                result["\(key)"] = value
            }
        }
        return result
    }
    
    /// Парсинг исходных данных (conversionData или deepLink) в нашу модель AppsFlyerAttributionModel
    /// Парсинг исходных данных (conversionData или deepLink) в нашу модель AppsFlyerAttributionModel
    private func parseAttribution(from data: [String: Any], source: String) -> AppsFlyerAttributionModel {
        print("📡 [AppsFlyerAttributionService] parseAttribution (source = \(source))")
        
        // af_status: "Organic" / "Non-organic"
        let afStatus = data["af_status"] as? String
        
        // Алиас кампании {key}
        let campaign = data["campaign"] as? String
        let key = campaign
        
        // Сабки
        let sub1 = (data["af_sub1"] ?? data["sub1"]) as? String
        let sub2 = (data["af_sub2"] ?? data["sub2"]) as? String
        let sub3 = (data["af_sub3"] ?? data["sub3"]) as? String
        let sub4 = (data["af_sub4"] ?? data["sub4"]) as? String
        let sub5 = (data["af_sub5"] ?? data["sub5"]) as? String
        let sub6 = (data["af_sub6"] ?? data["sub6"]) as? String
        let sub7 = (data["af_sub7"] ?? data["sub7"]) as? String
        
        // 🛠 ИСПРАВЛЕНИЕ ЗДЕСЬ:
        // Сначала ищем ID в данных ответа. Если нет — берем напрямую у SDK.
        var appsflyerId = data["af_user_id"] as? String ?? data["appsflyer_id"] as? String
        
        if appsflyerId == nil {
            appsflyerId = AppsFlyerLib.shared().getAppsFlyerUID()
            print("📡 [AppsFlyerAttributionService] В conversion_data не было ID, взяли напрямую из SDK: \(appsflyerId ?? "nil")")
        }
        
        let mediaSource = data["media_source"] as? String
        
        // Заполняем модель
        let model = AppsFlyerAttributionModel(
            afStatus: afStatus,
            key: key,
            sub1: sub1,
            sub2: sub2,
            sub3: sub3,
            sub4: sub4,
            sub5: sub5,
            sub6: sub6,
            sub7: sub7,
            appsflyerId: appsflyerId,
            mediaSource: mediaSource,
            campaign: campaign,
            rawData: data
        )
        
        print("📡 [AppsFlyerAttributionService] Итоговая модель атрибуции собрана")
        return model
    }
}
