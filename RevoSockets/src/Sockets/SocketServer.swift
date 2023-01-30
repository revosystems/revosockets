import Foundation
import Network
//https://rderik.com/blog/building-a-server-client-aplication-using-apple-s-network-framework/

open class SocketServer {
    let port: NWEndpoint.Port
    let listener: NWListener

    var debug:Bool = false
    
    private var connectionsByID: [Int: ServerConnection] = [:]

    public init(port: UInt16) throws {
        self.port = NWEndpoint.Port(rawValue: port)!
        listener = try NWListener(using: .tcp, on: self.port)
    }

    @discardableResult
    public func start(debug:Bool = false) throws -> Self {
        self.debug = debug
        log("Socket Server Starting...")
        listener.stateUpdateHandler   = stateDidChange(to:)
        listener.newConnectionHandler = didAccept(nwConnection:)
        listener.start(queue: .main)
        return self
    }

    func stateDidChange(to newState: NWListener.State) {
        switch newState {
        case .ready: log("Server ready.")
        case .failed(let error): log("Server failure, error: \(error.localizedDescription)")
        default: break
        }
    }

    private func didAccept(nwConnection: NWConnection) {
        let connection = ServerConnection(nwConnection: nwConnection)
        self.connectionsByID[connection.id] = connection
        connection.didStopCallback = { _ in
            self.connectionDidStop(connection)
        }
        connection.start()
        //connection.send(data: "Welcome you are connection: \(connection.id)".data(using: .utf8)!)
        //connection.dataReceivedCallback = onDataReceived(data:connection:)
        connection.dataReceivedCallback = { [unowned self] data, connection in
            print("Received data")
            onDataReceived(data: data, connection: connection)
        }
        log("Server did open connection \(connection.id)")
    }
    
    open func onDataReceived(data:Data, connection:ServerConnection){
        
    }

    private func connectionDidStop(_ connection: ServerConnection) {
        connectionsByID.removeValue(forKey: connection.id)
        log("Server did close connection \(connection.id)")
    }

    public func stop() {
        listener.stateUpdateHandler = nil
        listener.newConnectionHandler = nil
        listener.cancel()
        for connection in connectionsByID.values {
            connection.didStopCallback = nil
            connection.stop()
        }
        connectionsByID.removeAll()
    }
    
    private func log(_ message:String) {
        if !debug { return }
        debugPrint(message)
    }
}
