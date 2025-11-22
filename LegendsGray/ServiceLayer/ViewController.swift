//
//
//
//import UIKit
//import SwiftUI
//
///// RootViewController — корневой контроллер,
///// который решает, что открыть и умеет ПЕРЕЗАГРУЖАТЬСЯ при диплинке.
//final class RootViewController: UIViewController {
//
//    // MARK: - Dependencies
//
//    private let attributionService: AppsFlyerAttributionServicing
//    private let deviceIdsProvider: DeviceIdsProviding
//    private let flagsmithService: FlagsmithServicing
//    private let linkBuilder: LinkBuilder
//
//    // MARK: - State
//
//    /// Флаг, что мы уже один раз успешно загрузились
//    private var flowStarted = false
//
//    /// Текущая атрибуция
//    private var currentAttribution: AppsFlyerAttributionModel?
//    
//    /// Сохраненные ссылки (чтобы не качать их заново при диплинке)
//    private var cachedOfferLinks: OfferLinks?
//
//    // MARK: - Init
//
//    init(
//        attributionService: AppsFlyerAttributionServicing = AppsFlyerAttributionService.shared,
//        deviceIdsProvider: DeviceIdsProviding = DeviceIdsProvider(),
//        flagsmithService: FlagsmithServicing = FlagsmithService(),
//        linkBuilder: LinkBuilder = LinkBuilder()
//    ) {
//        self.attributionService = attributionService
//        self.deviceIdsProvider = deviceIdsProvider
//        self.flagsmithService = flagsmithService
//        self.linkBuilder = linkBuilder
//
//        super.init(nibName: nil, bundle: nil)
//        print("🧱 [RootViewController] Инициализирован")
//    }
//
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) не поддерживается")
//    }
//
//    // MARK: - Lifecycle
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        view.backgroundColor = .systemBackground
//        print("🧱 [RootViewController] viewDidLoad")
//
//        setupInitialLoadingState()
//        observeAttribution()
//
//        // Таймаут на случай, если AF молчит (только для первого запуска)
//        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
//            if !self.flowStarted {
//                print("⏳ [RootViewController] Таймаут 6 сек → запускаем флоу (Organic fallback)")
//                self.startFlowIfNeeded()
//            }
//        }
//    }
//    
//    // MARK: - UI
//
//    private func setupInitialLoadingState() {
//        // Очищаем старое (если есть)
//        view.subviews.forEach { $0.removeFromSuperview() }
//        
//        let label = UILabel()
//        label.text = "Loading..."
//        label.font = .systemFont(ofSize: 16, weight: .medium)
//        label.textColor = .secondaryLabel
//        label.translatesAutoresizingMaskIntoConstraints = false
//        view.addSubview(label)
//        NSLayoutConstraint.activate([
//            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
//        ])
//    }
//
//    // MARK: - Logic
//
//    private func observeAttribution() {
//        print("🔍 [RootViewController] Подписка на атрибуцию")
//
//        attributionService.observeAttribution { [weak self] model in
//            guard let self else { return }
//            print("🧱 [RootViewController] Получена атрибуция: \(model.afStatus ?? "nil") | DeepLink: \(model.sub1 ?? "nil")")
//            
//            self.currentAttribution = model
//            
//            if self.flowStarted {
//                // 🚨 ВАЖНО: Если мы уже работаем, но пришли новые данные (DeepLink)
//                print("🔄 [RootViewController] Пришли НОВЫЕ данные во время работы. Перезапускаем ссылку!")
//                self.handleDeepLinkUpdate()
//            } else {
//                // Первый запуск
//                self.startFlowIfNeeded()
//            }
//        }
//    }
//
//    private func startFlowIfNeeded() {
//        guard flowStarted == false else { return }
//        flowStarted = true
//        print("🧱 [RootViewController] Старт основного флоу")
//
//        // 1. Качаем ссылки из Flagsmith
//        fetchOfferLinks()
//    }
//    
//    private func handleDeepLinkUpdate() {
//        // Если ссылки уже скачаны, просто пересобираем финальный URL
//        if let links = cachedOfferLinks {
//            handleOfferLinks(links)
//        } else {
//            // Если вдруг ссылок нет (редкость), качаем заново
//            fetchOfferLinks()
//        }
//    }
//
//    private func fetchOfferLinks() {
//        print("🌐 [RootViewController] Запрос OfferLinks...")
//        flagsmithService.fetchOfferLinks { [weak self] links in
//            guard let self else { return }
//            
//            if let links {
//                self.cachedOfferLinks = links // Сохраняем в кэш
//                self.handleOfferLinks(links)
//            } else {
//                print("❌ [RootViewController] Flagsmith вернул nil. Открываем заглушку.")
//                self.openAppPlaceholder()
//            }
//        }
//    }
//
//    private func handleOfferLinks(_ links: OfferLinks) {
//        print("🌐 [RootViewController] Обработка ссылок...")
//
//        // 2. Определяем статус (при DeepLink'е мы считаем это как Non-organic)
//        // Если есть sub1 или sub2 — считаем это рекламным входом
//        let isDeepLink = currentAttribution?.sub1 != nil || currentAttribution?.sub2 != nil
//        let afStatus = isDeepLink ? "Non-organic" : currentAttribution?.afStatus
//        
//        print("🌐 [RootViewController] Итоговый статус для ссылки: \(afStatus ?? "nil")")
//
//        // 3. Выбираем baseURL
//        guard let baseURL = chooseBaseURL(from: links, afStatus: afStatus) else {
//            self.openAppPlaceholder()
//            return
//        }
//
//        // 4. Собираем параметры
//        let trackingParams = buildTrackingParams(afStatus: afStatus)
//
//        // 5. LinkBuilder
//        guard let finalURL = linkBuilder.buildLink(baseURL: baseURL, params: trackingParams) else {
//            self.openAppPlaceholder()
//            return
//        }
//
//        // 6. Открываем WebView (перезагружаем экран)
//        openWebView(with: finalURL)
//    }
//
//    // MARK: - Helpers
//
//    private func chooseBaseURL(from links: OfferLinks, afStatus: String?) -> URL? {
//        let normalizedStatus = afStatus?.lowercased()
//        
//        // Логика выбора
//        if normalizedStatus == "organic" {
//            return links.organicURL ?? links.fallbackURL
//        } else if let normalizedStatus {
//            return links.paidURL ?? links.fallbackURL
//        }
//        
//        // Fallback logic
//        return links.fallbackURL ?? links.organicURL ?? links.paidURL
//    }
//
//    private func buildTrackingParams(afStatus: String?) -> TrackingParams {
//        let attr = currentAttribution
//        return TrackingParams(
//            key: attr?.key,
//            sub1: attr?.sub1,
//            sub2: attr?.sub2,
//            sub3: attr?.sub3,
//            sub4: attr?.sub4,
//            sub5: attr?.sub5,
//            sub6: attr?.sub6,
//            sub7: attr?.sub7,
//            afStatus: afStatus,
//            appsflyerId: attr?.appsflyerId,
//            idfa: deviceIdsProvider.idfa,
//            idfv: deviceIdsProvider.idfv,
//            appId: deviceIdsProvider.appId
//        )
//    }
//
//    // MARK: - Navigation
//
//    private func openWebView(with url: URL) {
//        print("🌐 [RootViewController] ОТКРЫВАЕМ WebView: \(url.absoluteString)")
//        
//        // Проверяем, не открыт ли уже WebView. Если открыт — можем просто заменить.
//        // Для надежности пересоздаем контроллер.
//        let webVC = WebViewController(url: url)
//        replaceRoot(with: webVC)
//    }
//
//    private func openAppPlaceholder() {
//        print("🧱 [RootViewController] Заглушка")
//        let swiftUIView = StartView()
//        let hosting = UIHostingController(rootView: swiftUIView)
//        replaceRoot(with: hosting)
//    }
//
//    private func replaceRoot(with viewController: UIViewController) {
//        guard let window = UIApplication.shared.windows.first else { return }
//        
//        // Анимация перехода, чтобы не моргало
//        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
//            window.rootViewController = viewController
//        }, completion: nil)
//    }
//}


import UIKit
import SwiftUI

/// RootViewController — корневой контроллер с поддержкой "памяти" о статусе юзера.
final class RootViewController: UIViewController {

    // MARK: - Dependencies

    private let attributionService: AppsFlyerAttributionServicing
    private let deviceIdsProvider: DeviceIdsProviding
    private let flagsmithService: FlagsmithServicing
    private let linkBuilder: LinkBuilder

    // MARK: - State

    private var flowStarted = false
    private var currentAttribution: AppsFlyerAttributionModel?
    private var cachedOfferLinks: OfferLinks?

    // MARK: - Init

    init(
        attributionService: AppsFlyerAttributionServicing = AppsFlyerAttributionService.shared,
        deviceIdsProvider: DeviceIdsProviding = DeviceIdsProvider(),
        flagsmithService: FlagsmithServicing = FlagsmithService(),
        linkBuilder: LinkBuilder = LinkBuilder()
    ) {
        self.attributionService = attributionService
        self.deviceIdsProvider = deviceIdsProvider
        self.flagsmithService = flagsmithService
        self.linkBuilder = linkBuilder

        super.init(nibName: nil, bundle: nil)
        print("🧱 [RootViewController] Инициализирован")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        print("🧱 [RootViewController] viewDidLoad")

        setupInitialLoadingState()
        observeAttribution()

        // Таймаут
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            if !self.flowStarted {
                print("⏳ [RootViewController] Таймаут 6 сек → запускаем флоу")
                self.startFlowIfNeeded()
            }
        }
    }
    
    // MARK: - UI

    private func setupInitialLoadingState() {
        view.subviews.forEach { $0.removeFromSuperview() }
        let label = UILabel()
        label.text = "Loading..."
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Logic

    private func observeAttribution() {
        attributionService.observeAttribution { [weak self] model in
            guard let self else { return }
            print("🧱 [RootViewController] Получена атрибуция: \(model.afStatus ?? "nil")")
            
            self.currentAttribution = model
            
            // Если пришли данные Non-organic (или сабки), запоминаем это навсегда
            if self.isConsideredNonOrganic(model) {
                print("💾 [RootViewController] Юзер определен как Non-organic. Сохраняем статус.")
                UserStatusService.shared.isNonOrganicUser = true
            }
            
            if self.flowStarted {
                print("🔄 [RootViewController] Обновление данных (Hot Reload)")
                self.handleDeepLinkUpdate()
            } else {
                self.startFlowIfNeeded()
            }
        }
    }

    private func startFlowIfNeeded() {
        guard flowStarted == false else { return }
        flowStarted = true
        fetchOfferLinks()
    }
    
    private func handleDeepLinkUpdate() {
        if let links = cachedOfferLinks {
            handleOfferLinks(links)
        } else {
            fetchOfferLinks()
        }
    }

    private func fetchOfferLinks() {
        print("🌐 [RootViewController] Запрос OfferLinks...")
        flagsmithService.fetchOfferLinks { [weak self] links in
            guard let self else { return }
            
            if let links {
                self.cachedOfferLinks = links
                self.handleOfferLinks(links)
            } else {
                print("❌ [RootViewController] Flagsmith error. Заглушка.")
                self.openAppPlaceholder()
            }
        }
    }

    private func handleOfferLinks(_ links: OfferLinks) {
        // 1. Определяем финальный статус
        // Смотрим и на текущую атрибуцию, и на сохраненную "память"
        let isSavedNonOrganic = UserStatusService.shared.isNonOrganicUser
        let isCurrentNonOrganic = isConsideredNonOrganic(currentAttribution)
        
        // Если юзер хоть раз был paid — он навсегда paid
        let isPaid = isSavedNonOrganic || isCurrentNonOrganic
        let afStatus = isPaid ? "Non-organic" : "Organic"
        
        print("🌐 [RootViewController] Статус юзера: \(afStatus) (Saved: \(isSavedNonOrganic), Current: \(isCurrentNonOrganic))")

        // 2. Выбираем baseURL
        guard let baseURL = chooseBaseURL(from: links, isPaid: isPaid) else {
            self.openAppPlaceholder()
            return
        }

        // 3. Собираем параметры (всегда берем свежие из AppsFlyer, если они есть)
        let trackingParams = buildTrackingParams(afStatus: afStatus)

        // 4. Строим ссылку
        guard let finalURL = linkBuilder.buildLink(baseURL: baseURL, params: trackingParams) else {
            self.openAppPlaceholder()
            return
        }

        // 5. Открываем
        openWebView(with: finalURL)
    }

    // MARK: - Helpers
    
    /// Проверка, считать ли текущую модель "Рекламной"
    private func isConsideredNonOrganic(_ model: AppsFlyerAttributionModel?) -> Bool {
        guard let model else { return false }
        
        // 1. Явный статус
        if let status = model.afStatus?.lowercased(), status == "non-organic" {
            return true
        }
        // 2. Наличие сабок (Диплинк)
        if model.sub1 != nil || model.sub2 != nil {
            return true
        }
        return false
    }

    private func chooseBaseURL(from links: OfferLinks, isPaid: Bool) -> URL? {
        if isPaid {
            return links.paidURL ?? links.fallbackURL
        } else {
            return links.organicURL ?? links.fallbackURL
        }
    }

    private func buildTrackingParams(afStatus: String?) -> TrackingParams {
        let attr = currentAttribution
        return TrackingParams(
            key: attr?.key,
            sub1: attr?.sub1,
            sub2: attr?.sub2,
            sub3: attr?.sub3,
            sub4: attr?.sub4,
            sub5: attr?.sub5,
            sub6: attr?.sub6,
            sub7: attr?.sub7,
            afStatus: afStatus,
            appsflyerId: attr?.appsflyerId,
            idfa: deviceIdsProvider.idfa,
            idfv: deviceIdsProvider.idfv,
            appId: deviceIdsProvider.appId
        )
    }

    private func openWebView(with url: URL) {
        print("🌐 [RootViewController] ОТКРЫВАЕМ WebView: \(url.absoluteString)")
        let webVC = WebViewController(url: url)
        replaceRoot(with: webVC)
    }

    private func openAppPlaceholder() {
        print("🧱 [RootViewController] Заглушка")
        let swiftUIView = StartView()
        let hosting = UIHostingController(rootView: swiftUIView)
        replaceRoot(with: hosting)
    }

    private func replaceRoot(with viewController: UIViewController) {
        guard let window = UIApplication.shared.windows.first else { return }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            window.rootViewController = viewController
        }, completion: nil)
    }
}
