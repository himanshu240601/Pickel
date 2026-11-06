//
//  ImagePipelineEnvironment.swift
//  Pickel
//

import SwiftUI

private struct ImagePipelineKey: EnvironmentKey {
    static let defaultValue: ImagePipeline = .shared
}

extension EnvironmentValues {
    /// The pipeline used by ``PickelImage`` views. Defaults to
    /// ``ImagePipeline/shared``.
    public var imagePipeline: ImagePipeline {
        get { self[ImagePipelineKey.self] }
        set { self[ImagePipelineKey.self] = newValue }
    }
}

extension View {
    /// Sets the pipeline used by ``PickelImage`` views in this hierarchy.
    public func imagePipeline(_ pipeline: ImagePipeline) -> some View {
        environment(\.imagePipeline, pipeline)
    }
}
