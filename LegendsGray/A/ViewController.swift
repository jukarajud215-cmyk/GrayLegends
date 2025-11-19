//
//  ViewController.swift
//  LegendsGray
//
//  Created by D K on 18.11.2025.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }


}

import UIKit
import SwiftUI

/// RootViewController — корневой контроллер,
/// который решает, что открыть:
///  - WebView с трекинговой ссылкой
///  - или заглушку (StartView), если ссылки нет / ошибка
final class RootViewController: UIViewController {

    // MARK: - Dependencies

    /// Сервис атрибуции AppsFlyer
    private let attributionService: AppsFlyerAttributionServicing

    /// Провайдер девайс-идентификаторов (idfa, idfv, appId)
    private let deviceIdsProvider: DeviceIdsProviding

    /// Сервис для получения ссылок из Flagsmith
    private let flagsmithService: FlagsmithServicing

    /// Сборщик финальной ссылки
    private let linkBuilder: LinkBuilder

    // MARK: - State

    /// Флаг, чтобы не запускать флоу несколько раз
    private var flowStarted = false

    /// Текущая атрибуция (если уже пришла)
    private var currentAttribution: AppsFlyerAttributionModel?

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
        fatalError("init(coder:) не поддерживается, используй init(...)")
    }

    // MARK: - Lifecycle

//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        view.backgroundColor = .systemBackground
//        print("🧱 [RootViewController] viewDidLoad")
//
//        // Можно показать простой лоадер / сплэш, пока собираем данные
//        setupInitialLoadingState()
//
//        // Подписываемся на атрибуцию AppsFlyer
//        observeAttribution()
//
//        // Запускаем основной флоу
//        startFlowIfNeeded()
//    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        print("🧱 [RootViewController] viewDidLoad")

        setupInitialLoadingState()
        observeAttribution()

        /// ⏳ Даем AppsFlyer время выслать атрибуцию
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            print("⏳ [RootViewController] 2 sec delay passed → пробуем запустить флоу")
            self.startFlowIfNeeded()
        }
    }

    
    // MARK: - UI

    /// Простейший "заглушечный" стейт, пока мы ждём данные
    private func setupInitialLoadingState() {
        let label = UILabel()
        label.text = "Загрузка..."
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        print("🧱 [RootViewController] Показан базовый лоадер")
    }

    // MARK: - Attribution observing

//    /// Подписка на обновления атрибуции от AppsFlyerAttributionService
//    private func observeAttribution() {
//        attributionService.observeAttribution { [weak self] model in
//            guard let self else { return }
//            print("🧱 [RootViewController] Получена атрибуция от AppsFlyerAttributionService")
//            self.currentAttribution = model
//
//            // Как только атрибуция есть — пробуем запустить флоу
//            self.startFlowIfNeeded()
//        }
//    }

    
    private func observeAttribution() {
        print("🔍 [RootViewController] Запускаем наблюдение AppsFlyer Attribution")

        attributionService.observeAttribution { [weak self] model in
            guard let self else { return }
            print("🧱 [RootViewController] Атрибуция получена: \(model.afStatus ?? "nil")")
            self.currentAttribution = model
            self.startFlowIfNeeded()
        }

        /// ⚠️ Таймаут на случай, если AppsFlyer задержится или не даст данных
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.currentAttribution == nil {
                print("⚠️ [RootViewController] Attribution не пришла вовремя → стартуем без неё")
                self.startFlowIfNeeded()
            }
        }
    }

    // MARK: - Flow

    /// Запуск основного флоу (только один раз)
    private func startFlowIfNeeded() {
        guard flowStarted == false else {
            print("🧱 [RootViewController] startFlowIfNeeded — флоу уже запущен, выходим")
            return
        }

        flowStarted = true
        print("🧱 [RootViewController] Старт основного флоу")

        // 1. Получаем ссылки из Flagsmith
        fetchOfferLinks()
    }

    /// Получаем OfferLinks из Flagsmith
    private func fetchOfferLinks() {
        print("🌐 [RootViewController] Запрос OfferLinks из FlagsmithService")

        flagsmithService.fetchOfferLinks { [weak self] links in
            guard let self else { return }

            if let links {
                print("🌐 [RootViewController] Успешно получили OfferLinks из FlagsmithService")
                self.handleOfferLinks(links)
            } else {
                print("❌ [RootViewController] Не удалось получить OfferLinks. Открываем заглушку.")
                self.openAppPlaceholder()
            }
        }
    }

    /// Обработка полученных OfferLinks
    private func handleOfferLinks(_ links: OfferLinks) {
        print("🌐 [RootViewController] handleOfferLinks вызван")

        // 2. Определяем af_status (органика / реклама)
        let afStatus = currentAttribution?.afStatus
        print("🌐 [RootViewController] af_status = \(afStatus ?? "nil")")

        // 3. Выбираем baseURL на основе af_status
        guard let baseURL = chooseBaseURL(from: links, afStatus: afStatus) else {
            print("❌ [RootViewController] Не удалось выбрать baseURL из OfferLinks. Открываем заглушку.")
            openAppPlaceholder()
            return
        }

        // 4. Собираем TrackingParams
        let trackingParams = buildTrackingParams(afStatus: afStatus)

        // 5. Собираем финальную ссылку через LinkBuilder
        guard let finalURL = linkBuilder.buildLink(baseURL: baseURL, params: trackingParams) else {
            print("❌ [RootViewController] Не удалось собрать финальную ссылку. Открываем заглушку.")
            openAppPlaceholder()
            return
        }

        // 6. Открываем WebView с финальной ссылкой
        openWebView(with: finalURL)
    }

    // MARK: - Helpers

    /// Выбор baseURL по аф-статусу (органика / реклама / fallback)
    private func chooseBaseURL(from links: OfferLinks, afStatus: String?) -> URL? {
        let normalizedStatus = afStatus?.lowercased()

        if normalizedStatus == "organic" {
            // Органический трафик
            if let url = links.organicURL {
                print("🌐 [RootViewController] Выбран organicURL для af_status = Organic")
                return url
            } else if let fallback = links.fallbackURL {
                print("🌐 [RootViewController] Нет organicURL, используем fallbackURL для органики")
                return fallback
            }
        } else if let normalizedStatus {
            // Любой неорганический источник
            if let paid = links.paidURL {
                print("🌐 [RootViewController] Выбран paidURL для af_status = \(normalizedStatus)")
                return paid
            } else if let fallback = links.fallbackURL {
                print("🌐 [RootViewController] Нет paidURL, используем fallbackURL для атрибутированного трафика")
                return fallback
            }
        } else {
            print("🌐 [RootViewController] af_status = nil, не знаем органика это или нет")
        }

        // Если что-то пошло не так, пробуем fallback / organic / paid по приоритету
        if let fallback = links.fallbackURL {
            print("🌐 [RootViewController] Используем fallbackURL (как последний вариант)")
            return fallback
        } else if let organic = links.organicURL {
            print("🌐 [RootViewController] Используем organicURL (fallback отсутствует)")
            return organic
        } else if let paid = links.paidURL {
            print("🌐 [RootViewController] Используем paidURL (fallback и organic отсутствуют)")
            return paid
        }

        print("❌ [RootViewController] Нет ни одной валидной ссылки в OfferLinks")
        return nil
    }

    /// Сборка TrackingParams из атрибуции и девайс-идентификаторов
    private func buildTrackingParams(afStatus: String?) -> TrackingParams {
        print("🧱 [RootViewController] Сборка TrackingParams")

        let attribution = currentAttribution

        let params = TrackingParams(
            key: attribution?.key,
            sub1: attribution?.sub1,
            sub2: attribution?.sub2,
            sub3: attribution?.sub3,
            sub4: attribution?.sub4,
            sub5: attribution?.sub5,
            sub6: attribution?.sub6,
            sub7: attribution?.sub7,
            afStatus: afStatus,
            appsflyerId: attribution?.appsflyerId,
            idfa: deviceIdsProvider.idfa,
            idfv: deviceIdsProvider.idfv,
            appId: deviceIdsProvider.appId
        )

        print("🧱 [RootViewController] TrackingParams собраны")
        return params
    }

    // MARK: - Navigation

    /// Открыть WebView с финальной ссылкой
    private func openWebView(with url: URL) {
        print("🌐 [RootViewController] Открываем WebView с URL: \(url.absoluteString)")

        // Здесь мы предполагаем, что у нас будет WebViewController с init(url: URL)
        let webVC = WebViewController(url: url)

        // Меняем корневой контроллер нашего окна (чтобы не держать RootVC в стеке)
        replaceRoot(with: webVC)
    }

    /// Открыть SwiftUI-заглушку (StartView)
    private func openAppPlaceholder() {
        print("🧱 [RootViewController] Открываем заглушку (StartView)")

        let swiftUIView = StartView()
        let hosting = UIHostingController(rootView: swiftUIView)

        replaceRoot(with: hosting)
    }

    /// Helper для замены rootViewController у окна приложения
    private func replaceRoot(with viewController: UIViewController) {
        guard let window = UIApplication.shared.windows.first else {
            print("❌ [RootViewController] Не удалось найти окно для замены rootViewController")
            return
        }

        window.rootViewController = viewController
        window.makeKeyAndVisible()

        print("🧱 [RootViewController] rootViewController заменён на \(type(of: viewController))")
    }
}


