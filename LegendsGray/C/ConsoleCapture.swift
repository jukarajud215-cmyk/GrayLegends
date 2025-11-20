import Foundation

/// Класс, который перехватывает stdout/stderr и отправляет всё в AppLogger
final class ConsoleCapture {

    static let shared = ConsoleCapture()

    private var pipe: Pipe?
    private var readSource: DispatchSourceRead?

    private init() {}

//    func startCapture() {
//        // Чтобы не запустить дважды
//        guard pipe == nil else { return }
//
//        let pipe = Pipe()
//        self.pipe = pipe
//
//        let readHandle = pipe.fileHandleForReading
//        let writeFD = pipe.fileHandleForWriting.fileDescriptor
//
//        // Перенаправляем stdout и stderr в pipe
//        dup2(writeFD, STDOUT_FILENO)
//        dup2(writeFD, STDERR_FILENO)
//
//        // Настраиваем чтение из pipe
//        let source = DispatchSource.makeReadSource(fileDescriptor: readHandle.fileDescriptor,
//                                                   queue: .global(qos: .utility))
//        readSource = source
//
//        source.setEventHandler { [weak self] in
//            guard let self else { return }
//            let data = readHandle.availableData
//            guard !data.isEmpty else { return }
//
//            if let str = String(data: data, encoding: .utf8) {
//                self.processNewText(str)
//            }
//        }
//
//        source.setCancelHandler {
//            try? readHandle.close()
//        }
//
//        source.resume()
//    }

    func startCapture() {
            guard pipe == nil else { return }

            let pipe = Pipe()
            self.pipe = pipe

            let readHandle = pipe.fileHandleForReading
            let writeFD = pipe.fileHandleForWriting.fileDescriptor

            // Отключаем буферизацию stdout, чтобы логи летели мгновенно
            setvbuf(stdout, nil, _IONBF, 0)
            setvbuf(stderr, nil, _IONBF, 0)

            // Перенаправляем
            dup2(writeFD, STDOUT_FILENO)
            dup2(writeFD, STDERR_FILENO)

            let source = DispatchSource.makeReadSource(fileDescriptor: readHandle.fileDescriptor,
                                                       queue: .global(qos: .utility))
            readSource = source

            source.setEventHandler { [weak self] in
                guard let self else { return }
                // Читаем данные
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
            
            print("✅ [ConsoleCapture] Перехват логов включен (v2)")
        }
    
    private func processNewText(_ text: String) {
        // Могут прийти сразу несколько строк
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            AppLogger.shared.appendRawLine(line)
        }
    }

    func stopCapture() {
        readSource?.cancel()
        readSource = nil
        pipe = nil
    }
}
