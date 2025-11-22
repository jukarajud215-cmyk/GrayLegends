import Foundation

/// Единое место для всех ключей и настроек приложения
enum AppConfig {
    
    // MARK: - IDs & Keys
    
    /// Ключ API Flagsmith
    static let flagsmithApiKey = "6VMAUtutyrub5sZK38pFAS"
    
    /// Ключ разработчика AppsFlyer
    static let appsFlyerDevKey = "itFfAJovmtJH5U8iWeKajL"
    
    /// Числовой ID приложения в App Store (для трекинга и AppsFlyer)
    /// Пример: "6755430983"
    static let appleAppID = "6755430983"
    
    /// ID приложения в OneSignal
    static let oneSignalAppID = "4689da76-49e4-446b-9f5d-581b4a5d5cd5"
    
    // MARK: - WebView Settings
    
    /// Пользовательский User Agent.
    /// Если оставить nil — будет использоваться стандартный системный (рекомендуется).
    /// Если нужно жестко задать (например, для клоаки), впиши сюда строку.
    static let customUserAgent: String? = nil
    // Пример: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15..."
}
