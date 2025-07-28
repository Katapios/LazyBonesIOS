import Foundation

/// Ошибки API клиента
enum APIClientError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
    case serverError(Int)
    case unauthorized
    case forbidden
    case notFound
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .unauthorized:
            return "Unauthorized"
        case .forbidden:
            return "Forbidden"
        case .notFound:
            return "Not found"
        case .unknown:
            return "Unknown error"
        }
    }
}

/// HTTP методы
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

/// Заголовки запроса
typealias HTTPHeaders = [String: String]

/// Параметры запроса
typealias HTTPParameters = [String: Any]

/// Базовый API клиент
class APIClient {
    
    private let session: URLSession
    private let baseURL: String
    private let defaultHeaders: HTTPHeaders
    
    init(baseURL: String, session: URLSession = .shared, defaultHeaders: HTTPHeaders = [:]) {
        self.baseURL = baseURL
        self.session = session
        self.defaultHeaders = defaultHeaders
    }
    
    /// Выполнить GET запрос
    func get<T: Decodable>(_ endpoint: String, parameters: HTTPParameters? = nil, headers: HTTPHeaders? = nil) async throws -> T {
        return try await request(method: .GET, endpoint: endpoint, parameters: parameters, headers: headers)
    }
    
    /// Выполнить POST запрос
    func post<T: Decodable>(_ endpoint: String, parameters: HTTPParameters? = nil, body: Data? = nil, headers: HTTPHeaders? = nil) async throws -> T {
        return try await request(method: .POST, endpoint: endpoint, parameters: parameters, body: body, headers: headers)
    }
    
    /// Выполнить PUT запрос
    func put<T: Decodable>(_ endpoint: String, parameters: HTTPParameters? = nil, body: Data? = nil, headers: HTTPHeaders? = nil) async throws -> T {
        return try await request(method: .PUT, endpoint: endpoint, parameters: parameters, body: body, headers: headers)
    }
    
    /// Выполнить DELETE запрос
    func delete<T: Decodable>(_ endpoint: String, parameters: HTTPParameters? = nil, headers: HTTPHeaders? = nil) async throws -> T {
        return try await request(method: .DELETE, endpoint: endpoint, parameters: parameters, headers: headers)
    }
    
    /// Выполнить запрос с загрузкой файла
    func upload<T: Decodable>(_ endpoint: String, fileURL: URL, fieldName: String, parameters: HTTPParameters? = nil, headers: HTTPHeaders? = nil) async throws -> T {
        let url = try buildURL(endpoint: endpoint, parameters: parameters)
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.POST.rawValue
        
        // Установить заголовки
        let allHeaders = mergeHeaders(defaultHeaders, headers)
        allHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        // Создать multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Добавить параметры
        if let parameters = parameters {
            for (key, value) in parameters {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
        }
        
        // Добавить файл
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: fileURL))
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return try await performRequest(request)
    }
    
    // MARK: - Private Methods
    
    private func request<T: Decodable>(method: HTTPMethod, endpoint: String, parameters: HTTPParameters? = nil, body: Data? = nil, headers: HTTPHeaders? = nil) async throws -> T {
        let url = try buildURL(endpoint: endpoint, parameters: method == .GET ? parameters : nil)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        // Установить заголовки
        let allHeaders = mergeHeaders(defaultHeaders, headers)
        allHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        // Установить тело запроса
        if let body = body {
            request.httpBody = body
        } else if let parameters = parameters, method != .GET {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return try await performRequest(request)
    }
    
    private func buildURL(endpoint: String, parameters: HTTPParameters?) throws -> URL {
        var urlString = baseURL
        if !endpoint.hasPrefix("/") {
            urlString += "/"
        }
        urlString += endpoint
        
        guard var urlComponents = URLComponents(string: urlString) else {
            throw APIClientError.invalidURL
        }
        
        if let parameters = parameters {
            urlComponents.queryItems = parameters.map { key, value in
                URLQueryItem(name: key, value: "\(value)")
            }
        }
        
        guard let url = urlComponents.url else {
            throw APIClientError.invalidURL
        }
        
        return url
    }
    
    private func mergeHeaders(_ headers1: HTTPHeaders, _ headers2: HTTPHeaders?) -> HTTPHeaders {
        var merged = headers1
        if let headers2 = headers2 {
            merged.merge(headers2) { _, new in new }
        }
        return merged
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        Logger.debug("API Request: \(request.httpMethod ?? "Unknown") \(request.url?.absoluteString ?? "Unknown URL")", log: Logger.networking)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIClientError.unknown
            }
            
            Logger.debug("API Response: \(httpResponse.statusCode)", log: Logger.networking)
            
            // Проверить статус код
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                throw APIClientError.unauthorized
            case 403:
                throw APIClientError.forbidden
            case 404:
                throw APIClientError.notFound
            case 500...599:
                throw APIClientError.serverError(httpResponse.statusCode)
            default:
                throw APIClientError.serverError(httpResponse.statusCode)
            }
            
            // Декодировать ответ
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let result = try decoder.decode(T.self, from: data)
                return result
            } catch {
                Logger.error("Decoding error: \(error.localizedDescription)", log: Logger.networking)
                throw APIClientError.decodingError
            }
            
        } catch let error as APIClientError {
            throw error
        } catch {
            Logger.error("Network error: \(error.localizedDescription)", log: Logger.networking)
            throw APIClientError.networkError(error)
        }
    }
} 