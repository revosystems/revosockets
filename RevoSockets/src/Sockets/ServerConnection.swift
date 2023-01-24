import Foundation
import Network

public class ServerConnection {
    //The TCP maximum package size is 64K 65536
    let MTU = 65536

    private static var nextID: Int = 0
    let connection: NWConnection
    let id: Int
    
    var debug:Bool = false

    init(nwConnection: NWConnection) {
        connection = nwConnection
        id = ServerConnection.nextID
        ServerConnection.nextID += 1
    }

    var didStopCallback: ((Error?) -> Void)? = nil
    var dataReceivedCallback:((_ data:Data, _ connection:ServerConnection)->Void)? = nil

    func start() {
        log("Server Connection \(id) will start")
        connection.stateUpdateHandler = self.stateDidChange(to:)
        setupReceive()
        connection.start(queue: .main)
    }

    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error): connectionDidFail(error: error)
        case .ready: log("Server connection \(id) ready")
        case .failed(let error): connectionDidFail(error: error)
        default: break
        }
    }

    private func setupReceive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: MTU) { [unowned self] (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                let message = String(data: data, encoding: .utf8)
                log("Server connection \(self.id) did receive, data: \(data as NSData) string: \(message ?? "-")")
                didReceive(data:data)
            }
            if isComplete {
                connectionDidEnd()
            } else if let error = error {
                connectionDidFail(error: error)
            } else {
                setupReceive()
            }
        }
    }
    
    func didReceive(data:Data){
        dataReceivedCallback?(data, self)
    }

    public func send(data: Data) {
        connection.send(content: data, completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
            self.log("Server Connection \(self.id) did send, data: \(data as NSData)")
        }))
    }

    func stop() {
        log("Server connection \(id) will stop")
    }

    private func connectionDidFail(error: Error) {
        log("Server Connection \(id) did fail, error: \(error)")
        stop(error: error)
    }

    private func connectionDidEnd() {
        log("connection \(id) did end")
        stop(error: nil)
    }

    private func stop(error: Error?) {
        connection.stateUpdateHandler = nil
        connection.cancel()
        if let didStopCallback = didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
        }
    }
    
    private func log(_ message:String) {
        if !debug { return }
        debugPrint(message)
    }
}
