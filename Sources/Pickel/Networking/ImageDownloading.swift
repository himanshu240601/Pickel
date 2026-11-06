//
//  ImageDownloading.swift
//  Pickel
//
//  Created by Himanshu's MacBook on 11/10/26.
//

import Foundation

/// Fetches raw image bytes. Implement this to plug in a custom networking
/// stack; the default implementation is ``ImageDownloader``.
public protocol ImageDownloading: Sendable {
    func download(_ request: URLRequest) async throws -> Data
}

extension ImageDownloading {
    public func download(from url: URL) async throws -> Data {
        try await download(URLRequest(url: url))
    }
}
