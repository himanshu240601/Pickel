//
//  ImageDownloaderError.swift
//  Pickel
//
//  Created by Himanshu's MacBook on 11/10/26.
//

import Foundation

enum ImageDownloaderError: Error, Equatable {
    case invalidResponse
    case unacceptableStatusCode(Int)
}
