import SwiftUI

struct LogsView: View {

    @ObservedObject private var logger = AppLogger.shared
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""

    /// Отфильтрованные строки по поиску
    private var filteredLines: [String] {
        let all = logger.lines
        guard !searchText.isEmpty else { return all }
        let q = searchText.lowercased()
        return all.filter { $0.lowercased().contains(q) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // Поиск
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Поиск по логам", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .padding([.horizontal, .top], 12)

                // Текст логов
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredLines.indices, id: \.self) { idx in
                            Text(filteredLines[idx])
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                }
                .background(Color.black)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Copy all") {
                            copyAll()
                        }
                        Button("Clear logs", role: .destructive) {
                            logger.clear()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private func copyAll() {
        let text = logger.allText(filteredWith: searchText)
        UIPasteboard.general.string = text
    }
}
