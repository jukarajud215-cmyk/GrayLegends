import UIKit
import SwiftUI
import OneSignalFramework

/// RootViewController — Вечный контейнер.
/// Он никогда не исчезает, а просто меняет контент внутри себя.
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
    
    /// Ссылка на текущий показанный контроллер (WebView или StartView)
    private var currentChildViewController: UIViewController?
    
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
        print("🧱 [RootViewController] Инициализирован (Container Mode)")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // Показываем лоадер, пока ждем решения
        setupInitialLoadingState()
        
        // Подписываемся
        observeAttribution()
        
        // Таймаут
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            if !self.flowStarted {
                print("⏳ [RootViewController] Таймаут 6 сек → запускаем флоу")
                self.startFlowIfNeeded()
            }
        }
    }
    
    // MARK: - UI Setup
    
    private func setupInitialLoadingState() {
        // Если уже есть ребенок - не рисуем лоадер поверх
        if currentChildViewController != nil { return }
        
        let label = UILabel()
        label.text = "Loading..."
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        label.tag = 999 // Метка, чтобы потом удалить
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func removeLoadingState() {
        view.viewWithTag(999)?.removeFromSuperview()
    }
    
    // MARK: - Logic
    
    private func observeAttribution() {
        attributionService.observeAttribution { [weak self] model in
            guard let self else { return }
            print("🧱 [RootViewController] Получена атрибуция: \(model.afStatus ?? "nil")")
            
            self.currentAttribution = model
            
            if self.isConsideredNonOrganic(model) {
                print("💾 [RootViewController] Юзер Non-organic. Сохраняем статус.")
                UserStatusService.shared.isNonOrganicUser = true
            }
            
            if self.flowStarted {
                print("🔄 [RootViewController] Hot Reload: Пришли новые данные!")
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
        // Логика статуса
        let isSavedNonOrganic = UserStatusService.shared.isNonOrganicUser
        let isCurrentNonOrganic = isConsideredNonOrganic(currentAttribution)
        let isPaid = isSavedNonOrganic || isCurrentNonOrganic
        let afStatus = isPaid ? "Non-organic" : "Organic"
        
        print("🌐 [RootViewController] Решение: \(afStatus)")
        
        
        
        // Выбор URL
        guard let baseURL = chooseBaseURL(from: links, isPaid: isPaid) else {
            self.openAppPlaceholder()
            return
        }
        
        // Сборка параметров
        let trackingParams = buildTrackingParams(afStatus: afStatus)
        
        
        
        if let afId = trackingParams.appsflyerId {
            print("🔔 [RootViewController] Связываем OneSignal с AppsFlyer ID: \(afId)")
            OneSignal.login(afId)
        }
        
        guard let finalURL = linkBuilder.buildLink(baseURL: baseURL, params: trackingParams) else {
            self.openAppPlaceholder()
            return
        }
        
        // Показ
        openWebView(with: finalURL)
    }
    
    // MARK: - Helpers (Logic)
    
    private func isConsideredNonOrganic(_ model: AppsFlyerAttributionModel?) -> Bool {
        guard let model else { return false }
        if let status = model.afStatus?.lowercased(), status == "non-organic" { return true }
        if model.sub1 != nil || model.sub2 != nil { return true }
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
    
    // MARK: - Navigation (Container Logic) ⚠️ CHANGED
    
    private func openWebView(with url: URL) {
        print("🌐 [RootViewController] Переход на WebView: \(url.absoluteString)")
        
        // Если мы уже показываем WebView с ТАКОЙ ЖЕ ссылкой — не дергаемся
        // (Чтобы избежать бесконечных перезагрузок, если AF шлет апдейты)
        if let currentWeb = currentChildViewController as? WebViewController,
           currentWeb.initialURL == url { // Тут придется добавить св-во initialURL в WebVC, см. ниже
            print("🌐 [RootViewController] Эта ссылка уже открыта. Игнорируем.")
            return
        }
        
        let webVC = WebViewController(url: url)
        transition(to: webVC)
    }
    
    private func openAppPlaceholder() {
        print("🧱 [RootViewController] Переход на Заглушку")
        
        // Если заглушка уже открыта — не пересоздаем
        if currentChildViewController is UIHostingController<StartView> { return }
        
        let swiftUIView = StartView()
        let hosting = UIHostingController(rootView: swiftUIView)
        transition(to: hosting)
    }
    
    /// Главный метод смены экранов
    private func transition(to newVC: UIViewController) {
        // 1. Удаляем старый (если был)
        if let current = currentChildViewController {
            current.willMove(toParent: nil)
            current.view.removeFromSuperview()
            current.removeFromParent()
        }
        
        // 2. Убираем лоадер
        removeLoadingState()
        
        // 3. Добавляем новый как Child
        addChild(newVC)
        newVC.view.frame = view.bounds
        newVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(newVC.view)
        newVC.didMove(toParent: self)
        
        currentChildViewController = newVC
    }
}
