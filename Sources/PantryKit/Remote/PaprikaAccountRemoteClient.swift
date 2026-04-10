import Foundation

public protocol PaprikaAccountRemoteClient: Sendable {
    func login(emailAddress: String, password: String) async throws -> String
}

public enum PaprikaAccountRemoteClientError: Error, LocalizedError {
    case invalidResponse
    case missingToken
    case authenticationFailed(String)
    case serverRejected(String)
    case unexpectedStatusCode(Int, String?)
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Paprika returned an invalid response."
        case .missingToken:
            return "Paprika did not return a session token."
        case .authenticationFailed(let message):
            return message
        case .serverRejected(let message):
            return "Paprika rejected the login request: \(message)"
        case .unexpectedStatusCode(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Paprika login failed with HTTP \(statusCode): \(message)"
            }
            return "Paprika login failed with HTTP \(statusCode)."
        case .transport(let message):
            return "Paprika login request failed: \(message)"
        }
    }
}

public struct PaprikaSimpleAccountRemoteClient: PaprikaAccountRemoteClient {
    public static let defaultBaseURL = URL(string: "https://www.paprikaapp.com")!

    private let baseURL: URL
    private let urlSession: URLSession
    private let userAgent: String

    public init(
        baseURL: URL = Self.defaultBaseURL,
        urlSession: URLSession = .shared,
        userAgent: String = "paprika-pantry/0.1"
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.userAgent = userAgent
    }

    public func login(emailAddress: String, password: String) async throws -> String {
        let normalizedEmail = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/account/login/"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(Self.basicAuthorization(emailAddress: normalizedEmail, password: password), forHTTPHeaderField: "Authorization")
        request.httpBody = Self.formURLEncodedBody(emailAddress: normalizedEmail, password: password)

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PaprikaAccountRemoteClientError.invalidResponse
            }

            let payload = try? decodePayload(from: data)

            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                throw mapError(statusCode: httpResponse.statusCode, message: payload?.error ?? Self.string(from: data))
            }

            guard let payload else {
                throw PaprikaAccountRemoteClientError.invalidResponse
            }

            if let errorMessage = payload.error?.trimmedNonEmpty {
                throw mapError(statusCode: httpResponse.statusCode, message: errorMessage)
            }

            guard let token = payload.result?.token?.trimmedNonEmpty else {
                throw PaprikaAccountRemoteClientError.missingToken
            }

            return token
        } catch let error as PaprikaAccountRemoteClientError {
            throw error
        } catch {
            throw PaprikaAccountRemoteClientError.transport(error.localizedDescription)
        }
    }

    private func decodePayload(from data: Data) throws -> LoginResponse {
        if data.isEmpty {
            return LoginResponse(error: nil, result: nil)
        }

        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }

    private func mapError(statusCode: Int, message: String?) -> PaprikaAccountRemoteClientError {
        let normalizedMessage = message?.trimmedNonEmpty
        if statusCode == 401 || statusCode == 403 {
            return .authenticationFailed(normalizedMessage ?? "Paprika rejected the provided credentials.")
        }

        if let normalizedMessage {
            let lowered = normalizedMessage.lowercased()
            if lowered.contains("invalid") || lowered.contains("incorrect") || lowered.contains("rejected") {
                return .authenticationFailed(normalizedMessage)
            }

            return .serverRejected(normalizedMessage)
        }

        return .unexpectedStatusCode(statusCode, nil)
    }

    private static func basicAuthorization(emailAddress: String, password: String) -> String {
        let credentials = "\(emailAddress):\(password)"
        let encoded = Data(credentials.utf8).base64EncodedString()
        return "Basic \(encoded)"
    }

    private static func formURLEncodedBody(emailAddress: String, password: String) -> Data? {
        formURLEncodedString([
            ("email", emailAddress),
            ("password", password),
        ]).data(using: .utf8)
    }

    private static func formURLEncodedString(_ fields: [(String, String)]) -> String {
        fields
            .map { key, value in
                "\(percentEncode(key))=\(percentEncode(value))"
            }
            .joined(separator: "&")
    }

    private static func percentEncode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._* ")
        return value
            .addingPercentEncoding(withAllowedCharacters: allowed)?
            .replacingOccurrences(of: " ", with: "+")
            ?? value
    }

    private static func string(from data: Data) -> String? {
        guard let string = String(data: data, encoding: .utf8)?.trimmedNonEmpty else {
            return nil
        }

        return string
    }
}

private struct LoginResponse: Decodable {
    let error: String?
    let result: LoginResult?
}

private struct LoginResult: Decodable {
    let token: String?
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
