import Foundation

public enum PaprikaRemoteClientError: Error, LocalizedError {
    case invalidResponse
    case unexpectedStatusCode(Int, String?)
    case invalidPayload(String)
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Paprika returned an invalid response."
        case .unexpectedStatusCode(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Paprika sync request failed with HTTP \(statusCode): \(message)"
            }
            return "Paprika sync request failed with HTTP \(statusCode)."
        case .invalidPayload(let message):
            return "Paprika returned an unexpected payload: \(message)"
        case .transport(let message):
            return "Paprika sync request failed: \(message)"
        }
    }
}

public struct PaprikaTokenRemoteClient: PaprikaRemoteClient {
    public static let defaultBaseURL = URL(string: "https://www.paprikaapp.com")!

    private let token: String
    private let baseURL: URL
    private let urlSession: URLSession
    private let userAgent: String

    public init(
        token: String,
        baseURL: URL = Self.defaultBaseURL,
        urlSession: URLSession = .shared,
        userAgent: String = "paprika-pantry/0.1"
    ) {
        self.token = token
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.userAgent = userAgent
    }

    public func listRecipeStubs() async throws -> [RemoteRecipeStub] {
        let data = try await get(path: "api/v1/sync/recipes/")
        let payload = try arrayPayload(from: data, expected: "recipe stub list")
        return try payload.map(decodeRecipeStub)
    }

    public func listRecipeCategories() async throws -> [RemoteRecipeCategory] {
        let data = try await get(path: "api/v1/sync/categories/")
        let payload = try arrayPayload(from: data, expected: "category list")
        return try payload.map(decodeCategory)
    }

    public func fetchRecipe(uid: String) async throws -> RemoteRecipe {
        let data = try await get(path: "api/v1/sync/recipe/\(uid)/")
        let payload = try objectPayload(from: data, expected: "recipe detail")
        return try decodeRecipe(payload, rawJSON: rawJSONString(from: data))
    }

    private func get(path: String) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PaprikaRemoteClientError.invalidResponse
            }

            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                throw PaprikaRemoteClientError.unexpectedStatusCode(
                    httpResponse.statusCode,
                    String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            return data
        } catch let error as PaprikaRemoteClientError {
            throw error
        } catch {
            throw PaprikaRemoteClientError.transport(error.localizedDescription)
        }
    }

    private func arrayPayload(from data: Data, expected: String) throws -> [[String: Any]] {
        let object = try jsonObject(from: data)
        if let array = object as? [[String: Any]] {
            return array
        }

        if let dictionary = object as? [String: Any],
           let array = dictionary["result"] as? [[String: Any]] {
            return array
        }

        throw PaprikaRemoteClientError.invalidPayload("Expected \(expected) array.")
    }

    private func objectPayload(from data: Data, expected: String) throws -> [String: Any] {
        let object = try jsonObject(from: data)
        if let dictionary = object as? [String: Any] {
            if let nested = dictionary["result"] as? [String: Any] {
                return nested
            }
            return dictionary
        }

        throw PaprikaRemoteClientError.invalidPayload("Expected \(expected) object.")
    }

    private func jsonObject(from data: Data) throws -> Any {
        do {
            return try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw PaprikaRemoteClientError.invalidPayload(error.localizedDescription)
        }
    }

    private func rawJSONString(from data: Data) throws -> String {
        guard let string = String(data: data, encoding: .utf8) else {
            throw PaprikaRemoteClientError.invalidPayload("Recipe payload was not valid UTF-8.")
        }
        return string
    }

    private func decodeRecipeStub(_ object: [String: Any]) throws -> RemoteRecipeStub {
        let uid = try requiredString("uid", in: object, expected: "recipe stub")
        let name = stringValue(for: "name", in: object) ?? uid
        return RemoteRecipeStub(
            uid: uid,
            name: name,
            hash: stringValue(for: "hash", in: object),
            isDeleted: boolValue(for: "deleted", in: object) ?? false
        )
    }

    private func decodeCategory(_ object: [String: Any]) throws -> RemoteRecipeCategory {
        let uid = try requiredString("uid", in: object, expected: "category")
        let name = stringValue(for: "name", in: object) ?? uid
        return RemoteRecipeCategory(
            uid: uid,
            name: name,
            isDeleted: boolValue(for: "deleted", in: object) ?? false
        )
    }

    private func decodeRecipe(_ object: [String: Any], rawJSON: String) throws -> RemoteRecipe {
        let uid = try requiredString("uid", in: object, expected: "recipe")
        let name = try requiredString("name", in: object, expected: "recipe")

        return RemoteRecipe(
            uid: uid,
            name: name,
            categoryReferences: stringArrayValue(for: "categories", in: object),
            sourceName: firstString(in: object, keys: ["source", "source_name"]),
            ingredients: stringValue(for: "ingredients", in: object),
            directions: stringValue(for: "directions", in: object),
            notes: stringValue(for: "notes", in: object),
            starRating: firstInt(in: object, keys: ["rating", "star_rating"]),
            isFavorite: firstBool(in: object, keys: ["on_favorites", "favorite", "is_favorite"]) ?? false,
            prepTime: stringValue(for: "prep_time", in: object),
            cookTime: stringValue(for: "cook_time", in: object),
            totalTime: stringValue(for: "total_time", in: object),
            servings: stringValue(for: "servings", in: object),
            createdAt: firstString(in: object, keys: ["created", "created_at"]),
            updatedAt: firstString(in: object, keys: ["updated", "updated_at", "modified"]),
            remoteHash: stringValue(for: "hash", in: object),
            rawJSON: rawJSON
        )
    }

    private func requiredString(_ key: String, in object: [String: Any], expected: String) throws -> String {
        guard let value = stringValue(for: key, in: object), !value.isEmpty else {
            throw PaprikaRemoteClientError.invalidPayload("Missing \(key) in \(expected).")
        }
        return value
    }

    private func firstString(in object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = stringValue(for: key, in: object) {
                return value
            }
        }
        return nil
    }

    private func firstInt(in object: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = intValue(for: key, in: object) {
                return value
            }
        }
        return nil
    }

    private func firstBool(in object: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            if let value = boolValue(for: key, in: object) {
                return value
            }
        }
        return nil
    }

    private func stringValue(for key: String, in object: [String: Any]) -> String? {
        guard let value = object[key] else {
            return nil
        }

        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private func intValue(for key: String, in object: [String: Any]) -> Int? {
        guard let value = object[key] else {
            return nil
        }

        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    private func boolValue(for key: String, in object: [String: Any]) -> Bool? {
        guard let value = object[key] else {
            return nil
        }

        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.intValue != 0
        case let string as String:
            switch string.lowercased() {
            case "true", "1", "yes":
                return true
            case "false", "0", "no":
                return false
            default:
                return nil
            }
        default:
            return nil
        }
    }

    private func stringArrayValue(for key: String, in object: [String: Any]) -> [String] {
        guard let value = object[key] else {
            return []
        }

        if let strings = value as? [String] {
            return strings
        }

        if let objects = value as? [[String: Any]] {
            return objects.compactMap { stringValue(for: "uid", in: $0) ?? stringValue(for: "name", in: $0) }
        }

        return []
    }
}
