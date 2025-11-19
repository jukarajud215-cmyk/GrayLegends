import Foundation
import FlagsmithClient   // или просто `import Flagsmith`, если у тебя так

/// Протокол для работы с Flagsmith.
/// Отвечает за получение JSON-конфига и преобразование его в OfferLinks.
protocol FlagsmithServicing {

    /// Получить ссылки для оффера (organic/paid/fallback) из Flagsmith.
    /// - Parameter completion: вернёт OfferLinks или nil, если что-то пошло не так.
    func fetchOfferLinks(completion: @escaping (OfferLinks?) -> Void)
}

/// Сервис для работы с Flagsmith.
///
/// Использует тот же подход, что у тебя в старом проекте:
///  - Flagsmith.shared.apiKey = "..."
///  - Flagsmith.shared.getValueForFeature(...)
///
final class FlagsmithService: FlagsmithServicing {

    // MARK: - Properties

    /// Ключ флага, в котором лежит JSON со ссылками.
    /// Например: "offer_links_config"
    private let flagKey: String

    /// JSONDecoder для декодинга OfferLinks
    private let decoder: JSONDecoder

    // MARK: - Init

    init(
        flagKey: String = "offer_links_config",
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.flagKey = flagKey
        self.decoder = decoder

        print("🌐 [FlagsmithService] Инициализирован с flagKey = \(flagKey)")
    }

    // MARK: - Public

    func fetchOfferLinks(completion: @escaping (OfferLinks?) -> Void) {
        print("🌐 [FlagsmithService] fetchOfferLinks вызван")

        // ВАЖНО: к этому моменту где-то (обычно в AppDelegate)
        // должно быть уже установлено:
        // Flagsmith.shared.apiKey = "YOUR_ENVIRONMENT_KEY"

        Flagsmith.shared.getValueForFeature(withID: flagKey, forIdentity: nil) { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let value):
                    // В твоём примере value?.stringValue — это JSON-строка
                    guard let jsonString = value?.stringValue else {
                        print("❌ [FlagsmithService] Флаг \(self.flagKey) есть, но stringValue = nil")
                        completion(nil)
                        return
                    }

                    print("🌐 [FlagsmithService] Получили JSON из Flagsmith: \(jsonString)")
                    let links = self.parseOfferLinks(from: jsonString)
                    completion(links)

                case .failure(let error):
                    print("❌ [FlagsmithService] Ошибка получения флага \(self.flagKey): \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Parsing helper

    /// Парсинг OfferLinks из JSON-строки.
    /// Это используется:
    ///  - когда Flagsmith вернул JSON в виде строки
    ///  - можно вызывать и в тестах
    func parseOfferLinks(from jsonString: String) -> OfferLinks? {
        print("🌐 [FlagsmithService] parseOfferLinks(from:) вызван")
        print("🌐 [FlagsmithService] Входящий JSON: \(jsonString)")

        guard let data = jsonString.data(using: .utf8) else {
            print("❌ [FlagsmithService] Не удалось преобразовать JSON-строку в Data")
            return nil
        }

        do {
            let links = try decoder.decode(OfferLinks.self, from: data)
            print("✅ [FlagsmithService] Успешно распарсили OfferLinks из JSON")
            return links
        } catch {
            print("❌ [FlagsmithService] Ошибка декодинга OfferLinks: \(error)")
            return nil
        }
    }
}
