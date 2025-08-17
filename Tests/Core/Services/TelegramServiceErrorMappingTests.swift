import XCTest
@testable import LazyBones

private final class TestURLProtocol: URLProtocol {
    static var statusCode: Int = 200
    static var responseBody: Data? = nil

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url ?? URL(string: "https://example.com")!
        let resp = HTTPURLResponse(url: url, statusCode: Self.statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        if let body = Self.responseBody {
            client?.urlProtocol(self, didLoad: body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class TelegramServiceErrorMappingTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(TestURLProtocol.self)
        TestURLProtocol.responseBody = nil
    }

    override func tearDown() {
        URLProtocol.unregisterClass(TestURLProtocol.self)
        super.tearDown()
    }

    // MARK: - getMe
    func testGetMe_401_Unauthorized_MapsToInvalidToken() async {
        // Given
        TestURLProtocol.statusCode = 401
        let service = TelegramService(token: "tok")

        // When
        do {
            _ = try await service.getMe()
            XCTFail("Expected error")
        } catch let err as TelegramServiceError {
            // Then
            switch err {
            case .invalidToken: break
            default: XCTFail("Expected invalidToken, got: \(err)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - sendMessage
    func testSendMessage_401_Unauthorized_MapsToInvalidToken() async {
        // Given
        TestURLProtocol.statusCode = 401
        let service = TelegramService(token: "tok")

        // When
        do {
            try await service.sendMessage("hi", to: "123")
            XCTFail("Expected error")
        } catch let err as TelegramServiceError {
            // Then
            switch err {
            case .invalidToken: break
            default: XCTFail("Expected invalidToken, got: \(err)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testSendMessage_400_BadRequest_MapsToInvalidChatId() async {
        // Given
        TestURLProtocol.statusCode = 400
        let service = TelegramService(token: "tok")

        // When
        do {
            try await service.sendMessage("hi", to: "bad")
            XCTFail("Expected error")
        } catch let err as TelegramServiceError {
            // Then
            switch err {
            case .invalidChatId: break
            default: XCTFail("Expected invalidChatId, got: \(err)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testSendMessage_403_Forbidden_MapsToInvalidChatId() async {
        // Given
        TestURLProtocol.statusCode = 403
        let service = TelegramService(token: "tok")

        // When
        do {
            try await service.sendMessage("hi", to: "bad")
            XCTFail("Expected error")
        } catch let err as TelegramServiceError {
            // Then
            switch err {
            case .invalidChatId: break
            default: XCTFail("Expected invalidChatId, got: \(err)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testSendMessage_404_NotFound_MapsToInvalidChatId() async {
        // Given
        TestURLProtocol.statusCode = 404
        let service = TelegramService(token: "tok")

        // When
        do {
            try await service.sendMessage("hi", to: "bad")
            XCTFail("Expected error")
        } catch let err as TelegramServiceError {
            // Then
            switch err {
            case .invalidChatId: break
            default: XCTFail("Expected invalidChatId, got: \(err)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
