import Foundation

public class SocketServerReader {
    let delimiter:String
    var data:Data = Data()
    
    public init(delimiter:String){
        self.delimiter = delimiter
    }
    
    public func onDataReceived(_ newData:Data) -> String? {
        data.append(newData)
        
        let string = String(decoding: data, as: UTF8.self)
        guard string.contains(delimiter) else { return nil }
        
        defer { data = Data() }
        return string
    }
}
