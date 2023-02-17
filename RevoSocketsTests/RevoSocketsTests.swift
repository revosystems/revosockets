//
//  RevoSocketsTests.swift
//  RevoSocketsTests
//
//  Created by Jordi Puigdellívol on 23/1/23.
//

import XCTest
@testable import RevoSockets

final class RevoSocketsTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func test_socket_works() async throws {
        let _ = try PingSocketServer(port: 8989).start()
        let client = SocketClient(host: "127.0.0.1", port: 8989)
        try await client.start().send("Hello")
        
        let expectation = XCTestExpectation(description: "socket")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let response = try! client.read()
            let responseString = String(data: response, encoding: .utf8)
            XCTAssertEqual("Hello", responseString)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 4)
    }
    
    func test_socket_works_and_can_read_until_a_value() async throws {
        let _ = try PingSocketServer(port: 8989).start()
        let client = SocketClient(host: "127.0.0.1", port: 8989)
        
        try await client.start().send("Hello Baby#With a Separator")
        
        let response = try await client.read(to: "#")
        let responseString = String(data: response, encoding: .utf8)
        XCTAssertEqual("Hello Baby", responseString)
        XCTAssertEqual("With a Separator", String(data:client.connection.data, encoding: .utf8))
    }
    
    
    func test_socket_works_and_can_read_until_a_value_and_no_value_found_returns_a_timeout() async throws {
        let _ = try PingSocketServer(port: 8989).start()
        let client = SocketClient(host: "127.0.0.1", port: 8989)
        
        try await client.start().send("Hello Baby Without a Separator")
        do {
            let _ = try await client.read(to: "#", timeoutMs:1000)
            XCTFail("Timeout exception should have been thrown")
        }
        catch {
            XCTAssertTrue(true)
            return
        }
        XCTFail("Should have quited before")
    }
    
    
    func test_socket_send_and_read_on_single_command_works() async throws {
        let _ = try PingSocketServer(port: 8989).start()
        
        let client = SocketClient(host: "127.0.0.1", port: 8989)
        let response = try await client.start()
                             .send("Hello Baby#With a Separator")
                             .readAsString(to: "#")
        
        XCTAssertEqual("Hello Baby", response)
        XCTAssertEqual("With a Separator", String(data:client.connection.data, encoding: .utf8))
    }
    
    func test_socket_read_up_to_a_decode() async throws {
        struct Demo : Decodable {
            let name:String
            let age:Int
            let hasSuperPowers:Bool
        }
        
        let _ = try PingSocketServer(port: 8989).start()
        
        let json =
        """
        {
            "name":"Batman",
            "age": 45,
            "hasSuperPowers" : false
        }
       """
        let client = SocketClient(host: "127.0.0.1", port: 8989)
        let response = try await client.start()
                             .send(json)
                             .read(to: Demo.self)
        
        XCTAssertEqual("Batman", response?.name)
        XCTAssertEqual(45, response?.age)
        XCTAssertFalse(response!.hasSuperPowers)
        
        
        let json2 =
        """
        {
            "name":"Spiderman",
            "age": 16,
            "hasSuperPowers" : true
        }
       """
        let response2 = try await client
                             .send(json2)
                             .read(to: Demo.self)
        
        XCTAssertEqual("Spiderman", response2?.name)
        XCTAssertEqual(16, response2?.age)
        XCTAssertTrue(response2!.hasSuperPowers)
    }
    
    func test_no_available_has_a_timeout() async {
        let client = SocketClient(host: "10.0.0.5", port: 2000, connectionTimeoutSeconds:2)
        let expectation = XCTestExpectation(description: "Exception thrown")
        do {
            try await client.start()
                .send("")
                .read(to: "#")
        }catch{
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 15)
    }

}
