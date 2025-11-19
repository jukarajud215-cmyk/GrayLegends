import Foundation

/// Модель ссылок, которые мы получаем из Flagsmith.
///
/// Ожидаемый JSON (как пример):
/// {
///   "organic_url": "https://example.com/organic",
///   "paid_url": "https://example.com/paid",
///   "fallback_url": "https://example.com/fallback"
/// }
///
/// Храним строки, а наружу даём computed URL'ы, чтобы:
///  - не падать, если ссылка битая
///  - можно было логировать ошибки парсинга
///
struct OfferLinks: Decodable {

    // MARK: - Raw string values from JSON

    /// Ссылка для органического трафика (как строка из JSON)
    private let organicURLString: String?

    /// Ссылка для атрибутированного (рекламного) трафика
    private let paidURLString: String?

    /// Запасная ссылка (если нет ни органики, ни paid или что-то пошло не так)
    private let fallbackURLString: String?

    // MARK: - Public computed URLs

    /// URL для органического трафика
    var organicURL: URL? {
        url(from: organicURLString, label: "organic_url")
    }

    /// URL для атрибутированного трафика
    var paidURL: URL? {
        url(from: paidURLString, label: "paid_url")
    }

    /// Запасной URL
    var fallbackURL: URL? {
        url(from: fallbackURLString, label: "fallback_url")
    }

    // MARK: - Init / Decodable

    enum CodingKeys: String, CodingKey {
        case organicURLString = "organic_url"
        case paidURLString = "paid_url"
        case fallbackURLString = "fallback_url"
    }

    init(
        organicURLString: String?,
        paidURLString: String?,
        fallbackURLString: String?
    ) {
        self.organicURLString = organicURLString
        self.paidURLString = paidURLString
        self.fallbackURLString = fallbackURLString

        print("🌐 [OfferLinks] Инициализированы OfferLinks (init manual)")
        debugPrintRawValues()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.organicURLString = try container.decodeIfPresent(String.self, forKey: .organicURLString)
        self.paidURLString = try container.decodeIfPresent(String.self, forKey: .paidURLString)
        self.fallbackURLString = try container.decodeIfPresent(String.self, forKey: .fallbackURLString)

        print("🌐 [OfferLinks] Инициализированы OfferLinks (init from decoder)")
        debugPrintRawValues()
    }

    // MARK: - Private helpers

    /// Преобразуем строку в URL и логируем возможные проблемы
    private func url(from string: String?, label: String) -> URL? {
        guard let string = string, string.isEmpty == false else {
            print("🌐 [OfferLinks] \(label) отсутствует или пустой")
            return nil
        }

        guard let url = URL(string: string) else {
            print("❌ [OfferLinks] Не удалось создать URL из \(label): \(string)")
            return nil
        }

        print("🌐 [OfferLinks] \(label) = \(url.absoluteString)")
        return url
    }

    /// Логируем сырые строковые значения для отладки
    private func debugPrintRawValues() {
        print("🌐 [OfferLinks] Raw organic_url = \(organicURLString ?? "nil")")
        print("🌐 [OfferLinks] Raw paid_url = \(paidURLString ?? "nil")")
        print("🌐 [OfferLinks] Raw fallback_url = \(fallbackURLString ?? "nil")")
    }
}
