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
        guard #available(iOS 14, *) else {
            // Для старых iOS сразу просим пуши (если нужно)
            return
        }
        guard attRequested == false else { return }
        attRequested = true

        print("🔐 [ATT] Запрос разрешения...")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ATTrackingManager.requestTrackingAuthorization { status in
                print("🔐 [ATT] Статус: \(status.rawValue)")
                // После ATT можно инициализировать что-то ещё, если нужно
            }
        }
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
