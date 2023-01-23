import Foundation
import Network

public class SocketClient {
    let connection: ClientConnection
    let host: NWEndpoint.Host
    let port: NWEndpoint.Port
    
    var debug:Bool = false
    
    enum Errors : Error {
        case connectionError
        case timeout
        case connectionNotReady
    }

    init(host: String, port: UInt16) {
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(rawValue: port)!
        let nwConnection = NWConnection(host: self.host, port: self.port, using: .tcp)
        connection = ClientConnection(nwConnection: nwConnection)
    }

    //MARK: - LifeCycle
    @discardableResult
    func start(debug:Bool = false) async throws -> Self {
        self.debug = debug
        log("Client started \(host) \(port)")
        connection.debug = debug
        connection.didStopCallback = didStopCallback(error:)
        try await connection.start()
        return self
    }

    func stop() {
        connection.stop()
    }

    //MARK: - Send
    @discardableResult
    func send(_ string:String) -> Self {
        send(string.data(using: .utf8))
    }
    
    @discardableResult
    func send(_ data: Data?) -> Self {
        guard let data else { return self }
        connection.send(data: data)
        return self
    }
    
    //MARK: - Read
    func readAsString(clearBuffer:Bool = true) throws -> String? {
        try String(data: read(clearBuffer: clearBuffer), encoding: .utf8)
    }
        
    func read(clearBuffer:Bool = true) throws -> Data {
        try SocketClientReader(connection: connection).read(clearBuffer: clearBuffer)
    }
    
    func readAsString(to delimiter:String, timeoutMs:Double = 10000) async throws -> String? {
        let data = try await read(to: delimiter.data(using: .utf8), timeoutMs: timeoutMs)
        return String(data: data, encoding: .utf8)
    }
    
    func read(to delimiter:String, timeoutMs:Double = 10000) async throws -> Data{
        try await read(to: delimiter.data(using: .utf8), timeoutMs: timeoutMs)
    }
    
    func read(to delimiter:Data?, timeoutMs:Double = 10000) async throws -> Data {
        try await SocketClientReader(connection: connection).read(to: delimiter, timeoutMs: timeoutMs)
    }
    
    func read<T:Decodable>(to:T.Type, timeoutMs:Double = 10000) async throws -> T? {
        try await SocketClientReader(connection: connection).read(to:to, timeoutMs: timeoutMs)
    }
    
    func clearBuffer(){
        connection.clearBuffer()
    }

    //MARK: - End
    func didStopCallback(error: Error?) {
        log("Socket Client : TODO HERE!!!")
        if error == nil {
            //exit(EXIT_SUCCESS)
        } else {
            //exit(EXIT_FAILURE)
        }
    }
    
    private func log(_ message:String) {
        if !debug { return }
        debugPrint(message)
    }
}


