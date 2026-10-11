//
//  ImageDownloading.swift
//  Pickel
//
//  Created by Himanshu's MacBook on 11/10/26.
//

import Foundation

protocol ImageDownloading: Sendable {
    func download(from url: URL) async throws -> Data
}
