import Foundation
import Network

public class SocketClient {
    public var connection: ClientConnection
    public let host: NWEndpoint.Host
    public let port: NWEndpoint.Port
    
    var debug:Bool = false
    
    public enum Errors : Error {
        case connectionError
        case timeout
        case connectionNotReady
    }

    public init(host: String, port: UInt16, connectionTimeoutSeconds:Int? = 10) {
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(rawValue: port)!
        
        if let connectionTimeoutSeconds {
            let options = NWProtocolTCP.Options()
            options.connectionTimeout = connectionTimeoutSeconds
            
            let params = NWParameters(tls: nil, tcp: options)
            if let isOption = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
                isOption.version = .v4
            }
            params.preferNoProxies = true
            
            connection = ClientConnection(nwConnection: NWConnection(host: self.host, port: self.port, using: params))
        }else{
            connection = ClientConnection(nwConnection: NWConnection(host: self.host, port: self.port, using: .tcp))
        }
    }

    //MARK: - LifeCycle
    /**
    Connects to the socket and lets the connection open
     */
    @discardableResult
    public func start(debug:Bool = false) async throws -> Self {
        if isReady { return self }
        if connection.nwConnection.state == .cancelled {
            connection = ClientConnection(nwConnection: NWConnection(host: self.host, port: self.port, using: .tcp))
        }
        self.debug = debug
        log("Client started \(host) \(port)")
        connection.debug = debug
        connection.didStopCallback = didStopCallback(error:)
        try await connection.start()
        return self
    }

    /**
    Closes the connection
     */
    public func stop() {
        connection.stop()
    }

    //MARK: - Send
    /**
    Converts the string to data and sends it throught the socket
     */
    @discardableResult
    public func send(_ string:String) -> Self {
        send(string.data(using: .utf8))
    }
    
    /**
    Sends the data throught the socket
     */
    @discardableResult
    public func send(_ data: Data?) -> Self {
        guard let data else { return self }
        connection.send(data: data)
        return self
    }
    
    //MARK: - Read
    /**
     Gets whatever arrived to the socket and converts it to string
     @param clearBuffer reads and clears the buffer if true, when fale, the buffer is not emptied
     */
    public func readAsString(clearBuffer:Bool = true) throws -> String? {
        try String(data: read(clearBuffer: clearBuffer), encoding: .utf8)
    }
        
    public func read(clearBuffer:Bool = true) throws -> Data {
        try SocketClientReader(connection: connection).read(clearBuffer: clearBuffer)
    }
    
    public func readAsString(to delimiter:String, timeoutMs:Double = 10000) async throws -> String? {
        guard #available(iOS 16, *) else {
            let data = try await SocketClientReader(connection: connection).oldRead(to: delimiter.data(using: .utf8), timeoutMs: timeoutMs)
            return String(data: data, encoding: .utf8)
        }
        let data = try await read(to: delimiter.data(using: .utf8), timeoutMs: timeoutMs)
        return String(data: data, encoding: .utf8)        
    }
    
    public func read(to delimiter:String, timeoutMs:Double = 10000) async throws -> Data {
        guard #available(iOS 16, *) else {
            return try await SocketClientReader(connection: connection).oldRead(to: delimiter.data(using: .utf8), timeoutMs: timeoutMs)
        }
        return try await read(to: delimiter.data(using: .utf8), timeoutMs: timeoutMs)
    }
    
    @available(iOS 16.0, *)
    public func read(to delimiter:Data?, timeoutMs:Double = 10000) async throws -> Data {
        try await SocketClientReader(connection: connection).read(to: delimiter, timeoutMs: timeoutMs)
    }
    
    public func read<T:Decodable>(to:T.Type, timeoutMs:Double = 10000) async throws -> T? {
        try await SocketClientReader(connection: connection).read(to:to, timeoutMs: timeoutMs)
    }
    
    public func clearBuffer(){
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
    
    public var isReady:Bool {
        connection.nwConnection.state == .ready
    }
}


