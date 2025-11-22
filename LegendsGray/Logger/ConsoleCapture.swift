
import Foundation

/// Класс, который перехватывает stdout/stderr, ФИЛЬТРУЕТ мусор и отправляет чистое в AppLogger
final class ConsoleCapture {

    static let shared = ConsoleCapture()

    private var pipe: Pipe?
    private var readSource: DispatchSourceRead?

    // Список маркеров, которые мы ХОТИМ видеть.
    // Всё остальное (OSLOG, CFNetwork, Connection) будет игнорироваться.
    private let allowedPrefixes = [
        "✅", "🧱", "📡", "📱", "🌐", "🔗", "🔍", "🔔", "❌", "⚠️", "⏳", "🔄"
    ]
    
    private let allowedTags = [
        "[AppsFlyer]",
        "[OneSignal]", // Оставляем, если вдруг OneSignal что-то важное скажет через наш принт
        "[RootViewController]",
        "[AppDelegate]",
        "[LinkBuilder]",
        "[Flagsmith]",
        "[DeviceIdsProvider]",
        "[SceneDelegate]",
        "[WebViewController]"
    ]

    private init() {}

    func startCapture() {
        guard pipe == nil else { return }

        let pipe = Pipe()
        self.pipe = pipe

        let readHandle = pipe.fileHandleForReading
        let writeFD = pipe.fileHandleForWriting.fileDescriptor

        // Отключаем буферизацию
        setvbuf(stdout, nil, _IONBF, 0)
        setvbuf(stderr, nil, _IONBF, 0)

        // Перенаправляем stdout и stderr
        dup2(writeFD, STDOUT_FILENO)
        dup2(writeFD, STDERR_FILENO)

        let source = DispatchSource.makeReadSource(fileDescriptor: readHandle.fileDescriptor,
                                                   queue: .global(qos: .utility))
        readSource = source

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let data = readHandle.availableData
            guard !data.isEmpty else { return }

            if let str = String(data: data, encoding: .utf8) {
                self.processNewText(str)
            }
        }

        source.setCancelHandler {
            try? readHandle.close()
        }

        source.resume()
        
        // Этот принт попадет в лог, так как содержит ✅
        print("✅ [ConsoleCapture] Логгер включен (Strict Filter Mode)")
    }

    private func processNewText(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            // 1. Пропускаем пустые строки
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            
            // 2. ПРОВЕРКА: Является ли строка "нашей"?
            if isAppLog(line) {
                AppLogger.shared.appendRawLine(line)
            }
        }
    }
    
    /// Проверяет, содержит ли строка наши маркеры
    private func isAppLog(_ line: String) -> Bool {
        // Если строка начинается с наших эмодзи
        for prefix in allowedPrefixes {
            if line.contains(prefix) { return true }
        }
        
        // Или если содержит наши текстовые теги (на случай, если эмодзи забыли)
        for tag in allowedTags {
            if line.contains(tag) { return true }
        }
        
        // Если ничего не найдено — считаем это системным мусором (OSLOG...)
        return false
    }

    func stopCapture() {
        readSource?.cancel()
        readSource = nil
        pipe = nil
    }
}
