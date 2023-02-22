import Foundation

struct SocketClientReader {
    let connection:ClientConnection
    
    init(connection:ClientConnection) throws {
        guard connection.nwConnection.state == .ready else {
            throw SocketClient.Errors.connectionNotReady
        }
        self.connection = connection
    }
    
    func read(clearBuffer:Bool = true) -> Data {
        let data = connection.data
        if clearBuffer { connection.clearBuffer() }
        return data
    }
    

    func oldRead(to delimiter:Data?, timeoutMs:Double = 10000) async throws -> Data {
        guard let delimiter else { return Data() }
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                var timeSpent:Double = 0
                while !connection.data.oldContains(delimiter) {
                    if timeSpent > timeoutMs {
                        return continuation.resume(throwing: SocketClient.Errors.timeout)
                    }
                    try await Task.sleep(nanoseconds: 100_000_000)   //1_000_000_000 => Seconds
                    timeSpent += 100
                }
                let datas = connection.data.split(separator: delimiter)
                if datas.count > 1 {
                    connection.data = Data(datas[1...].joined(separator: delimiter))
                }else{
                    connection.clearBuffer()
                }
                continuation.resume(returning: datas.first ?? Data())
            }
        }
    }
    
    @available(iOS 16.0, *)
    func read(to delimiter:Data?, timeoutMs:Double = 10000) async throws -> Data {
        guard let delimiter else { return Data() }
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                var timeSpent:Double = 0
                while !connection.data.contains(delimiter) {
                    if timeSpent > timeoutMs {
                        return continuation.resume(throwing: SocketClient.Errors.timeout)
                    }
                    try await Task.sleep(nanoseconds: 100_000_000)   //1_000_000_000 => Seconds
                    timeSpent += 100
                }
                let datas = connection.data.split(separator: delimiter)
                if datas.count > 1 {
                    connection.data = Data(datas[1...].joined(separator: delimiter))
                }else{
                    connection.clearBuffer()
                }
                continuation.resume(returning: datas.first ?? Data())
            }
        }
    }
    
    func read<T:Decodable>(to:T.Type, timeoutMs:Double = 10000) async throws -> T? {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                var timeSpent:Double = 0
                var result:T? = nil
                while result == nil {
                    if timeSpent > timeoutMs {
                        return continuation.resume(throwing: SocketClient.Errors.timeout)
                    }
                    result = try? JSONDecoder().decode(to, from: connection.data)
                    if result == nil {
                        try await Task.sleep(nanoseconds: 100_000_000)  //1_000_000_000 => Seconds
                        timeSpent += 100
                    }
                }
                connection.clearBuffer()
                continuation.resume(returning: result)
            }
        }
    }
}

private extension Data {
    func split(separator: Data) -> [Data] {
        var chunks: [Data] = []
        var pos = startIndex
        // Find next occurrence of separator after current position:
        while let r = self[pos...].range(of: separator) {
            // Append if non-empty:
            if r.lowerBound > pos {
                chunks.append(self[pos..<r.lowerBound])
            }
            // Update current position:
            pos = r.upperBound
        }
        // Append final chunk, if non-empty:
        if pos < endIndex {
            chunks.append(self[pos..<endIndex])
        }
        return chunks
    }
    
    func oldContains(_ needle:Data) -> Bool {
        range(of: needle) != nil
    }
}
