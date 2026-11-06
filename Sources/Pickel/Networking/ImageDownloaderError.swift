//
//  ImageDownloaderError.swift
//  Pickel
//
//  Created by Himanshu's MacBook on 11/10/26.
//

import Foundation

/// Errors thrown by ``ImageDownloader``.
public enum ImageDownloaderError: Error, Equatable, Sendable {
    /// The response was not an HTTP response.
    case invalidResponse
    /// The server responded with a status code outside `200..<300`.
    case unacceptableStatusCode(Int)
}
