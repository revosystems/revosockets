import Foundation
import Network

public class ClientConnection {

    public let nwConnection: NWConnection
    let queue = DispatchQueue(label: "Client connection Q")
    
    var data:Data = Data()
    
    var debug:Bool = false
    var socketDisconnected = false

    init(nwConnection: NWConnection) {
        self.nwConnection = nwConnection
    }

    var didStopCallback: ((Error?) -> Void)? = nil

    func start() async throws {
        if nwConnection.state == .ready {
            return
        }
        return try await withCheckedThrowingContinuation { continuation in
            log("Client connection will start")
            nwConnection.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                self.stateDidChange(to: state)
                if state == .preparing { return }
                guard state == .ready else {
                    return continuation.resume(throwing:SocketClient.Errors.connectionError)
                }
                self.setupReceive()
                self.nwConnection.stateUpdateHandler = self.stateDidChange(to:)
                continuation.resume()
            }
            nwConnection.start(queue: queue)
        }        
    }

    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error): connectionDidFail(error: error)
        case .ready: log("Client connection ready")
        case .failed(let error): connectionDidFail(error: error)
        default: break
        }
    }

    private func setupReceive() {
        nwConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (data, _, isComplete, error) in
            guard let self else { return }
            if let data = data, !data.isEmpty {
                let message = String(data: data, encoding: .utf8)
                self.log("Client connection did receive, data: \(data as NSData) string: \(message ?? "-" )")
                self.data.append(data)
            }
            if isComplete {
                self.connectionDidEnd()
            } else if let error = error {
                self.connectionDidFail(error: error)
            } else {
                self.setupReceive()
            }
        }
    }

    func send(data: Data) {
        nwConnection.send(content: data, completion: .contentProcessed( { [weak self] error in
            if let error = error {
                self?.connectionDidFail(error: error)
                return
            }
            self?.log("Client Connection did send, data: \(data as NSData)")
        }))
    }

    func stop() {
        log("Client Connection will stop")
        stop(error: nil)
    }
    
    func clearBuffer(){
        data = Data()
    }

    private func connectionDidFail(error: Error) {
        log("Client connection did fail, error: \(error)")
        socketDisconnected = true
        stop(error: error)
    }

    private func connectionDidEnd() {
        log("Client connection did end")
        stop(error: nil)
    }

    private func stop(error: Error?) {
        nwConnection.stateUpdateHandler = nil
        nwConnection.cancel()
        if let didStopCallback = self.didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
        }
    }
    
    private func log(_ message:String) {
        if !debug { return }
        debugPrint(message)
    }
}
