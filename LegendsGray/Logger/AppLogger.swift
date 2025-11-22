
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

