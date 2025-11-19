//import Foundation
//import UIKit
//import Combine
//
///// Глобальный логгер:
/////  - дублирует в print (чтобы видеть в Xcode / Console)
/////  - хранит логи в памяти (чтобы показать в SwiftUI-экране)
//final class AppLogger: ObservableObject {
//
//    static let shared = AppLogger()
//
//    /// Все строки логов (обновляются в main-треде)
//    @Published private(set) var lines: [String] = []
//
//    /// Ограничение по количеству строк
//    private let maxLines = 2000
//
//    private init() {}
//
//    /// Основной метод логирования
//    func log(_ message: String,
//             file: String = #file,
//             line: Int = #line) {
//
//        let fileName = (file as NSString).lastPathComponent
//        let time = Self.timeString()
//
//        let full = "[\(time)] [\(fileName):\(line)] \(message)"
//
//        // В обычную консоль
//        print(full)
//
//        // В наше хранилище (только из main-треда)
//        DispatchQueue.main.async {
//            self.lines.append(full)
//            if self.lines.count > self.maxLines {
//                self.lines.removeFirst(self.lines.count - self.maxLines)
//            }
//        }
//    }
//
//    /// Текст для копирования целиком
//    func allText(filteredWith filter: String? = nil) -> String {
//        let base = lines
//        if let filter, !filter.isEmpty {
//            return base
//                .filter { $0.lowercased().contains(filter.lowercased()) }
//                .joined(separator: "\n")
//        } else {
//            return base.joined(separator: "\n")
//        }
//    }
//
//    func clear() {
//        DispatchQueue.main.async {
//            self.lines.removeAll()
//        }
//    }
//
//    // MARK: - Helpers
//
//    private static func timeString() -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "HH:mm:ss.SSS"
//        return formatter.string(from: Date())
//    }
//}
//
///// Удобная функция, чтобы писать коротко:
///// LG("что-то произошло")
//func LG(_ text: String,
//        file: String = #file,
//        line: Int = #line) {
//    AppLogger.shared.log(text, file: file, line: line)
//}

import Foundation
import Combine

final class AppLogger: ObservableObject {

    static let shared = AppLogger()

    @Published private(set) var lines: [String] = []
    private let maxLines = 2000

    private init() {}

    func appendRawLine(_ line: String) {
        guard !line.isEmpty else { return }

        DispatchQueue.main.async {
            self.lines.append(line)
            if self.lines.count > self.maxLines {
                self.lines.removeFirst(self.lines.count - self.maxLines)
            }
        }
    }

    func allText(filteredWith filter: String? = nil) -> String {
        let base = lines
        guard let filter, !filter.isEmpty else {
            return base.joined(separator: "\n")
        }
        return base
            .filter { $0.lowercased().contains(filter.lowercased()) }
            .joined(separator: "\n")
    }

    func clear() {
        DispatchQueue.main.async {
            self.lines.removeAll()
        }
    }
}

