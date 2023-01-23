import Foundation
@testable import RevoSockets

class PingSocketServer : SocketServer {
    
    override func onDataReceived(data:Data, connection:ServerConnection){
        connection.send(data:data)
    }
}
