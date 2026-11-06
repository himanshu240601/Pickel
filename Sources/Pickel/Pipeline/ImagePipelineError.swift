//
//  ImagePipelineError.swift
//  Pickel
//

import Foundation

/// Errors thrown by ``ImagePipeline``.
public enum ImagePipelineError: Error, Equatable, Sendable {
    /// The request has no URL.
    case missingURL
    /// The request used ``ImageRequest/Options/returnCacheDataDontLoad``
    /// and no cached image was found.
    case cacheMiss
}
