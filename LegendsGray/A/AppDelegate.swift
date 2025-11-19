// itFfAJovmtJH5U8iWeKajL
// 6755430983

import UIKit
import AppsFlyerLib
import OneSignalFramework
import AppTrackingTransparency
import AdSupport
import FlagsmithClient

/// Главная точка входа в приложение
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    /// Окно приложения (используем без SceneDelegate)
    var window: UIWindow?
    private var attRequested = false

    // MARK: - UIApplicationDelegate

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
       ConsoleCapture.shared.startCapture()
        print("✅ [AppDelegate] didFinishLaunchingWithOptions старт")
        
        Flagsmith.shared.apiKey = "6VMAUtutyrub5sZK38pFAS"

        
        // 1. Настраиваем корневой контроллер (RootViewController)
        setupRootViewController()

        // 3. Инициализируем AppsFlyer SDK
        setupAppsFlyer()

        // 4. Инициализируем OneSignal для пуш-уведомлений
        setupOneSignal(with: launchOptions)

        print("✅ [AppDelegate] didFinishLaunchingWithOptions завершён")

        return true
    }

    
    func applicationDidBecomeActive(_ application: UIApplication) {
            requestATTIfNeeded()
        }

        private func requestATTIfNeeded() {
            guard #available(iOS 14, *) else {
                requestPushPermissionIfNeeded()
                return
            }
            guard attRequested == false else { return }
            attRequested = true

            let before = ATTrackingManager.trackingAuthorizationStatus
            print("🔐 [ATT] Статус ПЕРЕД запросом: \(before.rawValue)")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    print("🔐 [ATT] Статус ПОСЛЕ запроса: \(status.rawValue)")

                    // После ATT — уже можно спрашивать пуши
                    self.requestPushPermissionIfNeeded()
                }
            }
        }

        private func requestPushPermissionIfNeeded() {
            print("🔔 [Push] Запрос разрешения на пуши...")

            OneSignal.Notifications.requestPermission { accepted in
                print("🔔 [Push] Разрешение на пуши: \(accepted)")
            }
        }
    // MARK: - Root ViewController

    /// Устанавливаем RootViewController как корневой
    private func setupRootViewController() {
        print("🧱 [AppDelegate] Инициализация RootViewController")

        let window = UIWindow(frame: UIScreen.main.bounds)
        let rootVC = RootViewController()      // наш сервисный слой дальше рулит
        window.rootViewController = rootVC
        window.makeKeyAndVisible()
        self.window = window

        print("🧱 [AppDelegate] RootViewController установлен как корневой")
    }

    // MARK: - ATT (IDFA permission)

    /// Запрос разрешения на трекинг (AppTrackingTransparency)
    private func requestTrackingAuthorization() {
        if #available(iOS 14, *) {
            print("🔐 [ATT] Запрос разрешения на трекинг...")

            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .notDetermined:
                    print("🔐 [ATT] Статус: notDetermined")
                case .restricted:
                    print("🔐 [ATT] Статус: restricted")
                case .denied:
                    print("🔐 [ATT] Статус: denied (IDFA недоступен)")
                case .authorized:
                    print("🔐 [ATT] Статус: authorized (IDFA доступен)")
                @unknown default:
                    print("🔐 [ATT] Статус: unknown")
                }

                // ⚠️ При желании можно будет здесь уведомлять, что ATT получен,
                // чтобы DeviceIdsProvider уже мог корректно вернуть IDFA.
            }
        } else {
            print("🔐 [ATT] iOS < 14, ATT не требуется")
        }
    }
}

// MARK: - AppsFlyer

extension AppDelegate: AppsFlyerLibDelegate {

    /// Базовая настройка AppsFlyer SDK
    private func setupAppsFlyer() {
        print("📡 [AppsFlyer] Настройка AppsFlyer SDK...")

        let appsFlyerDevKey = "itFfAJovmtJH5U8iWeKajL"   // TODO: подставить реальный dev key
        let appleAppID      = "6755430983"              // TODO: подставить app id без "id" (например, "1234567890")

        let appsFlyer = AppsFlyerLib.shared()
        appsFlyer.appsFlyerDevKey = appsFlyerDevKey
        appsFlyer.appleAppID      = appleAppID
        appsFlyer.delegate        = self
        appsFlyer.isDebug         = true                 // ⚠️ В проде выключить

        // Старт SDK
        appsFlyer.start()
        print("📡 [AppsFlyer] AppsFlyerLib.start() вызван")
    }

    // MARK: - Conversion Data callbacks

    /// Успешное получение conversion data (первичная атрибуция)
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable : Any]) {
        print("📡 [AppsFlyer] onConversionDataSuccess вызван")
        print("📡 [AppsFlyer] Raw conversion data: \(conversionInfo)")

        // Прокидываем сырые данные в наш сервис атрибуции
        AppsFlyerAttributionService.shared.handleConversionData(conversionInfo)
    }

    /// Ошибка получения conversion data
    func onConversionDataFail(_ error: Error) {
        print("❌ [AppsFlyer] onConversionDataFail: \(error.localizedDescription)")

        // Здесь можно добавить fallback-логику, если надо (например, считать трафик органическим).
        // Пока просто логируем.
    }

    // MARK: - DeepLink callbacks

    /// Deep linking (отложенные / обычные диплинки от AppsFlyer)
    func onDeepLinking(_ result: DeepLinkResult) {
        print("📡 [AppsFlyer] onDeepLinking вызван")
        print("📡 [AppsFlyer] DeepLinkResult status: \(result.status)")
        print("📡 [AppsFlyer] DeepLinkResult error: \(String(describing: result.error))")

        // Прокидываем результат диплинка в наш сервис атрибуции
        AppsFlyerAttributionService.shared.handleDeepLink(result: result)
    }
}

// MARK: - Deep Link / URL handling (для AppsFlyer)

extension AppDelegate {

    /// Обработка URL-схем (custom URL schemes) для диплинков
    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        print("🌐 [DeepLink] application:open url: \(url.absoluteString)")

        // Передаём URL в AppsFlyer для обработки диплинка
        AppsFlyerLib.shared().handleOpen(url, options: options)
        return true
    }

    /// Обработка Universal Links (через NSUserActivity)
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        print("🌐 [DeepLink] application:continue userActivity: \(userActivity.activityType)")

        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        return true
    }
}

// MARK: - OneSignal

extension AppDelegate {

    /// Инициализация OneSignal SDK для пуш-уведомлений
//    private func setupOneSignal(with launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
//        print("🔔 [OneSignal] Настройка OneSignal...")
//
//        let oneSignalAppId = "4689da76-49e4-446b-9f5d-581b4a5d5cd5"     // TODO: подставить реальный OneSignal App ID
//
//        // Базовая инициализация OneSignal
//        OneSignal.initialize(oneSignalAppId, withLaunchOptions: launchOptions)
//        print("🔔 [OneSignal] OneSignal.initialize вызван")
//
//        // Запрашиваем разрешение на пуши (при желании можно перенести на более поздний момент)
//        OneSignal.Notifications.requestPermission { accepted in
//            print("🔔 [OneSignal] Разрешение на пуши: \(accepted)")
//        }
//
//        // Включаем подробное логирование OneSignal для отладки
//        OneSignal.Debug.setLogLevel(.LL_VERBOSE)
//        print("🔔 [OneSignal] Логирование OneSignal включено (VERBOSE)")
//    }
    
    private func setupOneSignal(with launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        print("🔔 [OneSignal] Настройка OneSignal...")

        let oneSignalAppId = "4689da76-49e4-446b-9f5d-581b4a5d5cd5"

        OneSignal.initialize(oneSignalAppId, withLaunchOptions: launchOptions)
        OneSignal.Debug.setLogLevel(.LL_VERBOSE)

        // ❌ БОЛЬШЕ НЕ ЗОВЕМ requestPermission здесь
        // OneSignal.Notifications.requestPermission { ... }
    }

}

