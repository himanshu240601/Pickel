//
//  StubDownloader.swift
//  Pickel
//

import Foundation
@testable import Pickel

/// Returns canned data per URL and records how many downloads happened.
actor StubDownloader: ImageDownloading {
    private var responses: [URL: Result<Data, any Error>] = [:]
    private(set) var requests: [URLRequest] = []

    var callCount: Int { requests.count }

    func setResponse(_ result: Result<Data, any Error>, for url: URL) {
        responses[url] = result
    }

    func download(_ request: URLRequest) async throws -> Data {
        requests.append(request)

        guard let url = request.url, let result = responses[url] else {
            throw URLError(.fileDoesNotExist)
        }

        return try result.get()
    }
}
