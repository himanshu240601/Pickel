//
//  ImageDownloader.swift
//  Pickel
//
//  Created by Himanshu's MacBook on 11/10/26.
//

import Foundation

/// Default ``ImageDownloading`` implementation backed by `URLSession`.
public struct ImageDownloader: ImageDownloading {
    private let session: URLSession

    public init(session: URLSession = ImageDownloader.makeDefaultSession()) {
        self.session = session
    }

    public func download(_ request: URLRequest) async throws -> Data {
        if let url = request.url, url.isFileURL {
            return try Data(contentsOf: url)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageDownloaderError.invalidResponse
        }

        let statusCode = httpResponse.statusCode

        guard (200..<300).contains(statusCode) else {
            throw ImageDownloaderError.unacceptableStatusCode(
                statusCode
            )
        }

        return data
    }

    /// A session tuned for image loading. `URLCache` is disabled because
    /// Pickel keeps its own disk cache.
    public static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 6
        configuration.timeoutIntervalForRequest = 60
        return URLSession(configuration: configuration)
    }
}
