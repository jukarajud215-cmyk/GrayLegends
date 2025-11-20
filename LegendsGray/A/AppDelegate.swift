import UIKit
import AppsFlyerLib
import OneSignalFramework
import AppTrackingTransparency
import AdSupport
import FlagsmithClient

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    private var attRequested = false
    
    // MARK: - UIApplicationDelegate
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        ConsoleCapture.shared.startCapture()
        print("✅ [AppDelegate] didFinishLaunchingWithOptions старт")
        
        // 1. Настраиваем Flagsmith через Config
        Flagsmith.shared.apiKey = AppConfig.flagsmithApiKey
        
        // 2. Настраиваем корневой контроллер
        setupRootViewController()
        
        // 3. Инициализируем AppsFlyer через Config
        setupAppsFlyer()
        
        // 4. Инициализируем OneSignal через Config
        setupOneSignal(with: launchOptions)
        
        print("✅ [AppDelegate] didFinishLaunchingWithOptions завершён")
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        requestATTIfNeeded()
    }
    
    private func requestATTIfNeeded() {
        // Если iOS старая (< 14), сразу просим пуши
        guard #available(iOS 14, *) else {
            requestPushPermissionIfNeeded()
            return
        }
        
        // Если уже спрашивали ATT — выходим
        guard attRequested == false else { return }
        attRequested = true
        
        print("🔐 [ATT] Запрос разрешения...")
        
        // Даем небольшую задержку, чтобы интерфейс успел прогрузиться
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ATTrackingManager.requestTrackingAuthorization { status in
                print("🔐 [ATT] Статус: \(status.rawValue)")
                
                // ВАЖНО: Как только юзер выбрал (или система ответила) по ATT,
                // сразу запрашиваем разрешение на ПУШИ.
                DispatchQueue.main.async {
                    self.requestPushPermissionIfNeeded()
                }
            }
        }
    }
    
    /// Метод для запроса пушей через OneSignal
    private func requestPushPermissionIfNeeded() {
        print("🔔 [Push] Запрос системного разрешения...")
        
        // OneSignal сам проверит, спрашивали мы уже или нет.
        // Если нет — покажет системный алерт.
        OneSignal.Notifications.requestPermission({ accepted in
            print("🔔 [Push] Пользователь ответил: \(accepted)")
        }, fallbackToSettings: true)
    }
    
    // MARK: - Setup Methods
    
    private func setupRootViewController() {
        print("🧱 [AppDelegate] Инициализация RootViewController")
        let window = UIWindow(frame: UIScreen.main.bounds)
        let rootVC = RootViewController()
        window.rootViewController = rootVC
        window.makeKeyAndVisible()
        self.window = window
    }
    
    private func setupAppsFlyer() {
        print("📡 [AppsFlyer] Настройка SDK...")
        
        let appsFlyer = AppsFlyerLib.shared()
        appsFlyer.appsFlyerDevKey = AppConfig.appsFlyerDevKey
        appsFlyer.appleAppID      = AppConfig.appleAppID
        appsFlyer.delegate        = self
        appsFlyer.isDebug         = true // ⚠️ Выключить перед релизом, если логов слишком много
        
        appsFlyer.start()
    }
    
    private func setupOneSignal(with launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        print("🔔 [OneSignal] Настройка SDK...")
        
        OneSignal.initialize(AppConfig.oneSignalAppID, withLaunchOptions: launchOptions)
        OneSignal.Debug.setLogLevel(.LL_VERBOSE)
    }
}

// MARK: - AppsFlyer Delegate (без изменений логики, просто для полноты)
extension AppDelegate: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable : Any]) {
        print("📡 [AppsFlyer] onConversionDataSuccess")
        AppsFlyerAttributionService.shared.handleConversionData(conversionInfo)
    }
    
    func onConversionDataFail(_ error: Error) {
        print("❌ [AppsFlyer] onConversionDataFail: \(error.localizedDescription)")
    }
    
    func onDeepLinking(_ result: DeepLinkResult) {
        print("📡 [AppsFlyer] onDeepLinking")
        AppsFlyerAttributionService.shared.handleDeepLink(result: result)
    }
}


// MARK: - Deep Linking (Handling URLs)

extension AppDelegate {

    /// 1. Обработка Universal Links (например, https://test134.onelink.me/...)
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        print("🔗 [AppDelegate] ПОЙМАЛИ Universal Link: \(userActivity.webpageURL?.absoluteString ?? "nil")")

        // Передаем ссылку в AppsFlyer
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        return true
    }

    /// 2. Обработка URI Schemes (например, legendsgray://...)
    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        print("🔗 [AppDelegate] ПОЙМАЛИ URI Scheme: \(url.absoluteString)")

        // Передаем ссылку в AppsFlyer
        AppsFlyerLib.shared().handleOpen(url, options: options)
        return true
    }
}
