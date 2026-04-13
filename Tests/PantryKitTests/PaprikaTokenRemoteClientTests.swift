import Foundation
import XCTest
@testable import PantryKit

final class PaprikaTokenRemoteClientTests: XCTestCase {
    override func tearDown() {
        MockPaprikaRemoteURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testListRecipeStubsUsesExpectedEndpointAndParsesDeletedFlag() async throws {
        MockPaprikaRemoteURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://www.paprikaapp.com/api/v1/sync/recipes/")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = #"""
            [
              {"uid":"AAA","name":"Soup","hash":"hash-1"},
              {"uid":"BBB","name":"Deleted","hash":"hash-2","deleted":1}
            ]
            """#.data(using: .utf8)!
            return (response, data)
        }

        let stubs = try await makeClient().listRecipeStubs()
        XCTAssertEqual(
            stubs,
            [
                RemoteRecipeStub(uid: "AAA", name: "Soup", hash: "hash-1"),
                RemoteRecipeStub(uid: "BBB", name: "Deleted", hash: "hash-2", isDeleted: true),
            ]
        )
    }

    func testListRecipeCategoriesParsesCategoryPayload() async throws {
        MockPaprikaRemoteURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://www.paprikaapp.com/api/v1/sync/categories/")

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = #"""
            [
              {"uid":"CAT1","name":"Dinner"},
              {"uid":"CAT2","name":"Archive","deleted":true}
            ]
            """#.data(using: .utf8)!
            return (response, data)
        }

        let categories = try await makeClient().listRecipeCategories()
        XCTAssertEqual(
            categories,
            [
                RemoteRecipeCategory(uid: "CAT1", name: "Dinner"),
                RemoteRecipeCategory(uid: "CAT2", name: "Archive", isDeleted: true),
            ]
        )
    }

    func testFetchRecipeParsesFirstSliceMetadataAndRawJSON() async throws {
        MockPaprikaRemoteURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://www.paprikaapp.com/api/v1/sync/recipe/AAA/")

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = #"""
            {
              "uid":"AAA",
              "name":"Weeknight Soup",
              "categories":["CAT1","CAT2"],
              "source":"Serious Eats",
              "ingredients":"Broth\nBeans",
              "directions":"Simmer.",
              "notes":"Finish with lemon.",
              "rating":4,
              "on_favorites":1,
              "prep_time":"10 min",
              "cook_time":"30 min",
              "total_time":"40 min",
              "servings":"4",
              "created":"2026-04-01 10:00:00",
              "updated":"2026-04-02 11:00:00",
              "hash":"hash-1"
            }
            """#.data(using: .utf8)!
            return (response, data)
        }

        let recipe = try await makeClient().fetchRecipe(uid: "AAA")
        XCTAssertEqual(recipe.uid, "AAA")
        XCTAssertEqual(recipe.name, "Weeknight Soup")
        XCTAssertEqual(recipe.categoryReferences, ["CAT1", "CAT2"])
        XCTAssertEqual(recipe.sourceName, "Serious Eats")
        XCTAssertEqual(recipe.ingredients, "Broth\nBeans")
        XCTAssertEqual(recipe.notes, "Finish with lemon.")
        XCTAssertEqual(recipe.starRating, 4)
        XCTAssertTrue(recipe.isFavorite)
        XCTAssertEqual(recipe.prepTime, "10 min")
        XCTAssertEqual(recipe.totalTime, "40 min")
        XCTAssertEqual(recipe.updatedAt, "2026-04-02 11:00:00")
        XCTAssertEqual(recipe.remoteHash, "hash-1")
        XCTAssertTrue(recipe.rawJSON.contains("\"Weeknight Soup\""))
    }

    private func makeClient() -> PaprikaTokenRemoteClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockPaprikaRemoteURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return PaprikaTokenRemoteClient(token: "token-123", urlSession: session)
    }
}

private final class MockPaprikaRemoteURLProtocol: URLProtocol {
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
