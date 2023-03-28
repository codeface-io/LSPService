@testable import LSPService
import XCTVapor

final class AppTests: XCTestCase {
    
    func testNonExistingPathIsNotFound() throws {
        let lspServiceApp = try LSPServiceApp(useTestEnvironment: true)
        
        try lspServiceApp.vaporApp.test(.GET, "invalidPath") { response in
            XCTAssertEqual(response.status, .notFound)
        }
    }
    
    // TODO: how do we test the websocket route?
//    func testGetSwiftWebSocket() throws {
//        let lspServiceApp = try LSPServiceApp(useTestEnvironment: true)
//        
//        try lspServiceApp.vaporApp.test(.GET,
//                                        "lspservice/api/swift/websocket") { response in
//            XCTAssertEqual(response.status, .ok)
//        }
//    }
    
    func testConfigForLanguageOfRandomNameIsNotSet() throws {
        XCTAssertNil(ServerExecutableConfigs.config(language: "jdfhbqrufghuidrgb"))
    }
    
    func testSwiftConfigIsSet() throws {
        XCTAssertNotNil(ServerExecutableConfigs.config(language: "swift"))
    }
}
