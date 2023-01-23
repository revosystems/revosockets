import Foundation
import Network

public class ClientConnection {

    let nwConnection: NWConnection
    let queue = DispatchQueue(label: "Client connection Q")
    
    var data:Data = Data()
    
    var debug:Bool = false

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
            //nwConnection.stateUpdateHandler = stateDidChange(to:)
            nwConnection.stateUpdateHandler = { [unowned self] state in
                stateDidChange(to: state)
                if state == .preparing { return }
                guard state == .ready else {
                    return continuation.resume(throwing:SocketClient.Errors.connectionError)
                }
                nwConnection.stateUpdateHandler = stateDidChange(to:)
                continuation.resume()
            }
            setupReceive()
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
        nwConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [unowned self] (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                let message = String(data: data, encoding: .utf8)
                log("Client connection did receive, data: \(data as NSData) string: \(message ?? "-" )")
                self.data.append(data)
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

    func send(data: Data) {
        nwConnection.send(content: data, completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
            self.log("Client Connection did send, data: \(data as NSData)")
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
