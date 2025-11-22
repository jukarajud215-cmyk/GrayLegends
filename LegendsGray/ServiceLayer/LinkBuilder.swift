import Foundation

/// Отвечает за сборку финальной трекинг-ссылки,
/// которую мы будем открывать в WebView.
///
/// На вход:
///  - baseURL: ссылка из Flagsmith (например, https://example.com)
///  - params: все наши сабки/идентификаторы (TrackingParams)
///
/// На выход:
///  - URL с query-параметрами, например:
///    https://example.com?key=...&sub1=...&idfa=...&idfv=...&app_id=...&appsflyer_id=...&af_status=...
///
final class LinkBuilder {

    // MARK: - Init

    init() {
        print("🔗 [LinkBuilder] Инициализирован")
    }

    // MARK: - Public

    /// Собирает финальный URL с параметрами.
    /// Если что-то пошло не так (не смогли собрать URLComponents) — вернёт nil.
    func buildLink(baseURL: URL, params: TrackingParams) -> URL? {
        print("🔗 [LinkBuilder] Старт сборки ссылки")
        print("🔗 [LinkBuilder] baseURL = \(baseURL.absoluteString)")

        // Разбираем baseURL в URLComponents, чтобы аккуратно работать с query
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            print("❌ [LinkBuilder] Не удалось создать URLComponents из baseURL")
            return nil
        }

        // Берём существующие queryItems, если они уже есть в baseURL
        var queryItems = components.queryItems ?? []

        // Хелпер для аккуратного добавления параметров
        func add(_ name: String, _ value: String?) {
            guard let value = value, value.isEmpty == false else {
                // Если значения нет — просто пропускаем
                return
            }
            let item = URLQueryItem(name: name, value: value)
            queryItems.append(item)
            print("🔗 [LinkBuilder] Добавлен query-параметр: \(name)=\(value)")
        }

        // MARK: - AppsFlyer / сабки / key / атрибуция

        add("key", params.key)

        add("sub1", params.sub1)
        add("sub2", params.sub2)
        add("sub3", params.sub3)
        add("sub4", params.sub4)
        add("sub5", params.sub5)
        add("sub6", params.sub6)
        add("sub7", params.sub7)

        add("af_status", params.afStatus)
        add("appsflyer_id", params.appsflyerId)

        // MARK: - Device IDs

        add("idfa", params.idfa)
        add("idfv", params.idfv)
        add("app_id", params.appId)

        // Присваиваем обновлённые queryItems обратно в components
        components.queryItems = queryItems

        // Формируем финальный URL
        let finalURL = components.url

        if let finalURL {
            print("✅ [LinkBuilder] Финальная ссылка собрана: \(finalURL.absoluteString)")
        } else {
            print("❌ [LinkBuilder] Не удалось собрать финальный URL из components")
        }

        return finalURL
    }
}
