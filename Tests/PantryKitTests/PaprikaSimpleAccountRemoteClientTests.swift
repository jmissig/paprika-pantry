import Foundation
import XCTest
@testable import PantryKit

final class PaprikaSimpleAccountRemoteClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testLoginSendsExpectedRequestAndReturnsToken() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://www.paprikaapp.com/api/v1/account/login/")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Content-Type"),
                "application/x-www-form-urlencoded; charset=utf-8"
            )
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Basic Y29va0BleGFtcGxlLmNvbTpzd29yZGZpc2g="
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "paprika-pantry/0.1")
            XCTAssertEqual(
                String(data: try XCTUnwrap(self.requestBody(for: request)), encoding: .utf8),
                "email=cook%40example.com&password=swordfish"
            )

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = #"{"result":{"token":"token-123"}}"#.data(using: .utf8)!
            return (response, data)
        }

        let token = try await makeClient().login(emailAddress: "cook@example.com", password: "swordfish")
        XCTAssertEqual(token, "token-123")
    }

    func testLoginSurfacesStructuredServerErrors() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 403,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = #"{"error":"Unrecognized client"}"#.data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await makeClient().login(emailAddress: "cook@example.com", password: "swordfish")
            XCTFail("Expected login to fail")
        } catch let error as PaprikaAccountRemoteClientError {
            XCTAssertEqual(error.errorDescription, "Unrecognized client")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoginUsesPlainTextErrorBodyWhenJSONIsUnavailable() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 500,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/plain"]
            )!
            let data = "upstream unavailable".data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await makeClient().login(emailAddress: "cook@example.com", password: "swordfish")
            XCTFail("Expected login to fail")
        } catch let error as PaprikaAccountRemoteClientError {
            XCTAssertEqual(
                error.errorDescription,
                "Paprika rejected the login request: upstream unavailable"
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeClient() -> PaprikaSimpleAccountRemoteClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return PaprikaSimpleAccountRemoteClient(urlSession: session)
    }

    private func requestBody(for request: URLRequest) throws -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count < 0 {
                throw try XCTUnwrap(stream.streamError)
            }
            if count == 0 {
                break
            }

            data.append(buffer, count: count)
        }

        return data
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            XCTFail("Missing request handler")
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
