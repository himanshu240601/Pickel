//
//  ImageDownloader.swift
//  Pickel
//
//  Created by Himanshu's MacBook on 11/10/26.
//

import Foundation

struct ImageDownloader {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func download(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        
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
}
