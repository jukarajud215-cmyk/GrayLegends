import SwiftUI

struct LogsView: View {

    @ObservedObject private var logger = AppLogger.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    
    // Категории для фильтрации
    enum LogFilter: String, CaseIterable {
        case all = "ALL"
        case relevant = "Relevant" // 🆕 Тот самый объединенный фильтр
        case af = "AppsFlyer"
        case web = "WebView"
        case links = "Link"
        case error = "Error"
    }
    
    @State private var selectedFilter: LogFilter = .all

    /// Вычисляем строки в реальном времени на основе чипа и поиска
    private var filteredLines: [String] {
        let all = logger.lines
        
        // 1. Фильтр по чипам
        let categoryFiltered: [String]
        switch selectedFilter {
        case .all:
            categoryFiltered = all
            
        case .relevant:
            // 🆕 Объединяем AF, Web и Links
            categoryFiltered = all.filter { line in
                let l = line.lowercased()
                return l.contains("appsflyer") || line.contains("📡") ||
                       l.contains("webview") || line.contains("🌐") ||
                       l.contains("linkbuilder") || line.contains("🔗") ||
                       l.contains("offerlinks")
            }
            
        case .af:
            categoryFiltered = all.filter { $0.contains("AppsFlyer") || $0.contains("📡") || $0.contains("af_") }
        case .web:
            categoryFiltered = all.filter { $0.contains("WebView") || $0.contains("🌐") }
        case .links:
            categoryFiltered = all.filter { $0.contains("LinkBuilder") || $0.contains("🔗") }
        case .error:
            categoryFiltered = all.filter { $0.contains("❌") || $0.lowercased().contains("error") || $0.contains("⚠️") }
        }
        
        // 2. Фильтр по текстовому поиску (если введен)
        guard !searchText.isEmpty else { return categoryFiltered }
        return categoryFiltered.filter { $0.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // Панель категорий (Chips)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LogFilter.allCases, id: \.self) { filter in
                            Button {
                                selectedFilter = filter
                            } label: {
                                Text(filter.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 14)
                                    .background(selectedFilter == filter ? Color.green : Color(UIColor.systemGray5))
                                    .foregroundColor(selectedFilter == filter ? .black : .white)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .background(Color.black)

                // Поле поиска
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search logs...", text: $searchText)
                        .foregroundColor(.white)
                        .accentColor(.green)
                }
                .padding(10)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                // Список логов
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        if filteredLines.isEmpty {
                            Text("No logs found")
                                .foregroundColor(.gray)
                                .padding(.top, 20)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(filteredLines, id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .foregroundColor(getColor(for: line))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding(8)
                }
                .background(Color.black)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Debug Console")
            .toolbar {
                // Кнопка Закрыть (слева)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                
                // Группа кнопок (справа)
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // 🆕 Кнопка Копировать (копирует только отфильтрованное)
                    Button {
                        copyFilteredLogs()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.green)
                    }
                    
                    // Кнопка Очистить
                    Button {
                        logger.clear()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Копирует в буфер обмена ТОЛЬКО то, что сейчас видно на экране (Filtered)
    private func copyFilteredLogs() {
        let textToCopy = filteredLines.joined(separator: "\n")
        UIPasteboard.general.string = textToCopy
        
        // Небольшая вибрация для подтверждения копирования
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Раскраска логов
    private func getColor(for line: String) -> Color {
        if line.contains("❌") { return .red }
        if line.contains("⚠️") { return .yellow }
        if line.contains("🔗") { return .cyan } // Ссылки
        if line.contains("🌐") { return .blue } // Flagsmith / Web
        if line.contains("📡") { return .purple } // AppsFlyer
        return .green
    }
}
