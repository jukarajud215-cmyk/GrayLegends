import SwiftUI
import WebKit
import UIKit

// MARK: - Coordinator

final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool

    /// Главный + все "попапные" WKWebView поверх него
    var webViewStack: [WKWebView] = []

    init(canGoBack: Binding<Bool>, canGoForward: Binding<Bool>) {
        _canGoBack = canGoBack
        _canGoForward = canGoForward
    }

    // Обновляем состояния кнопок
    func updateNavigationButtons(for webView: WKWebView) {
        canGoBack = webView.canGoBack || webViewStack.count > 1
        canGoForward = webView.canGoForward
    }

    // Навигация завершена
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateNavigationButtons(for: webView)
    }

    // Разрешение навигации
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
    {
        
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel); return
        }

        // Разрешённые "внутренние" схемы
        let scheme = (url.scheme ?? "").lowercased()
        let internalSchemes: Set<String> = ["http", "https", "about", "srcdoc", "blob", "data", "javascript", "file"]

        if internalSchemes.contains(scheme) {
            decisionHandler(.allow)
            return
        }

        // Иное — наружу
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        decisionHandler(.cancel)
    }

    // JS alert
    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void)
    {
        let ac = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        webView.window?.rootViewController?.present(ac, animated: true)
    }

    // window.open
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView?
    {
        
        // Фильтр поддельных about:blank/srcdoc/data/blob без реальных попапов
        let isRealPopup =
            (windowFeatures.width?.intValue ?? 0) > 0 ||
            (windowFeatures.height?.intValue ?? 0) > 0 ||
            (navigationAction.request.url?.absoluteString.contains("popup") == true)

        let lower = navigationAction.request.url?.absoluteString.lowercased() ?? ""
        let isSyntheticBlank = lower.isEmpty ||
                               lower == "about:blank" ||
                               lower == "about:srcdoc" ||
                               lower.hasPrefix("data:") ||
                               lower.hasPrefix("blob:")

        if !isRealPopup && isSyntheticBlank {
            return nil
        }

        // Создаём верхний WKWebView и кладём поверх
        let popup = WKWebView(frame: webView.bounds, configuration: configuration)
        popup.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        popup.navigationDelegate = self
        popup.uiDelegate = self
        popup.allowsBackForwardNavigationGestures = true

        webView.addSubview(popup)
        webView.bringSubviewToFront(popup)

        webViewStack.append(popup)
        updateNavigationButtons(for: popup)
        return popup
    }

    /// Закрывает самый верхний WKWebView из стека (когда назад уже некуда)
    func closeTopWebView() {
        guard webViewStack.count > 1 else { return }
        let top = webViewStack.removeLast()
        top.removeFromSuperview()
        if let visible = webViewStack.last {
            updateNavigationButtons(for: visible)
        }
    }
}

// MARK: - Representable

struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    
    // Убрали хардкод, теперь берем из конфига или используем nil
    let customUserAgent: String? = AppConfig.customUserAgent

    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var webView: WKWebView?

    var externalCoordinator: WebViewCoordinator?

    func makeCoordinator() -> WebViewCoordinator {
        externalCoordinator ?? WebViewCoordinator(canGoBack: $canGoBack, canGoForward: $canGoForward)
    }

    func makeUIView(context: Context) -> WKWebView {
        print("🌐 [WebView] Загрузка: \(url.absoluteString)")

        let prefs = WKPreferences()
        prefs.javaScriptCanOpenWindowsAutomatically = true

        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        cfg.allowsInlineMediaPlayback = true
        cfg.preferences = prefs
        
        // Устанавливаем UserAgent только если он задан в AppConfig
        if let ua = customUserAgent {
            cfg.applicationNameForUserAgent = ua
        }

        let wk = WKWebView(frame: .zero, configuration: cfg)
        wk.allowsBackForwardNavigationGestures = true
        wk.scrollView.delegate = context.coordinator
        wk.navigationDelegate = context.coordinator
        wk.uiDelegate = context.coordinator
        
        // Дополнительная установка UA (иногда applicationNameForUserAgent мало)
        if let ua = customUserAgent {
            wk.customUserAgent = ua
        }

        wk.load(URLRequest(url: url))

        context.coordinator.webViewStack = [wk]
        DispatchQueue.main.async { webView = wk }
        return wk
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }
}
// MARK: - Public SwiftUI view

struct CustomWebView: View {
    let url: URL
    var customUserAgent: String? = nil // передай MyConstants.webUserAgent при желании

    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var innerWebView: WKWebView?
    @State private var showLogs = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                WebViewRepresentable(
                            url: url,
                            canGoBack: $canGoBack,
                            canGoForward: $canGoForward,
                            webView: $innerWebView
                        )
                

                // Панель навигации
                HStack {
                    Button {
                        if let coord = (innerWebView?.navigationDelegate as? WebViewCoordinator),
                           let top = coord.webViewStack.last {
                            if top.canGoBack {
                                top.goBack()
                            } else if coord.webViewStack.count > 1 {
                                coord.closeTopWebView()
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(canGoBack ? .white : .gray)
                            .imageScale(.large)
                    }
                    .disabled(!canGoBack)
                    .padding(.horizontal)
                    .padding(.top, 12)

                    Spacer()

                    Button {
                        if let coord = (innerWebView?.navigationDelegate as? WebViewCoordinator) {
                            coord.webViewStack.last?.goForward()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(canGoForward ? .white : .gray)
                            .imageScale(.large)
                    }
                    .disabled(!canGoForward)
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
                .frame(height: 20)
                .background(Color.black)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .overlay(alignment: .bottomTrailing) {     // 👈 аккуратно кладём кнопку поверх
                   Button {
                      // LG("🧾 [CustomWebView] SHOW LOGS tapped")
                       showLogs = true
                   } label: {
                       Text("SHOW LOGS")
                           .font(.system(size: 12, weight: .semibold))
                           .foregroundColor(.white)
                           .padding(.horizontal, 12)
                           .padding(.vertical, 8)
                           .background(Color.red.opacity(0.8))
                           .cornerRadius(12)
                           .padding(.trailing, 16)
                           .padding(.bottom, 32)
                   }
               }
               .sheet(isPresented: $showLogs) {
                   LogsView()
               }
    }
}


final class WebViewController: UIHostingController<CustomWebView> {

    init(url: URL) {
        let rootView = CustomWebView(url: url)
        super.init(rootView: rootView)
        print("🌐 [WebViewController] Инициализирован с URL: \(url.absoluteString)")
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) не поддерживается")
    }
}
