//
//  ImageDownloader.swift
//  Pickel
//
//  Created by Himanshu's MacBook on 11/10/26.
//

import Foundation

/// Default ``ImageDownloading`` implementation backed by `URLSession`.
public struct ImageDownloader: ImageDownloading {
    /// Default limit for a single image: 50 MB.
    public static let defaultMaximumDataSize = 50 * 1024 * 1024

    private let session: URLSession
    private let maximumDataSize: Int

    /// - Parameters:
    ///   - session: Session used for network requests.
    ///   - maximumDataSize: Largest response accepted, in bytes. Larger
    ///     responses fail with ``ImageDownloaderError/responseTooLarge``.
    public init(
        session: URLSession = ImageDownloader.makeDefaultSession(),
        maximumDataSize: Int = ImageDownloader.defaultMaximumDataSize
    ) {
        self.session = session
        self.maximumDataSize = maximumDataSize
    }

    public func download(_ request: URLRequest) async throws -> Data {
        guard let url = request.url,
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "file"].contains(scheme)
        else {
            throw ImageDownloaderError.unsupportedURL
        }

        if url.isFileURL {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            guard size <= maximumDataSize else {
                throw ImageDownloaderError.responseTooLarge
            }
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

        guard data.count <= maximumDataSize else {
            throw ImageDownloaderError.responseTooLarge
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
