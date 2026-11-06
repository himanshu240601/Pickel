//
//  PickelImagePhaseTests.swift
//  Pickel
//

import SwiftUI
import XCTest
@testable import Pickel

final class PickelImagePhaseTests: XCTestCase {
    func testEmptyPhaseHasNoImageOrError() {
        let phase = PickelImagePhase.empty

        XCTAssertNil(phase.image)
        XCTAssertNil(phase.error)
    }

    func testSuccessPhaseExposesImage() {
        let phase = PickelImagePhase.success(Image(systemName: "star"))

        XCTAssertNotNil(phase.image)
        XCTAssertNil(phase.error)
    }

    func testFailurePhaseExposesError() {
        let phase = PickelImagePhase.failure(ImagePipelineError.cacheMiss)

        XCTAssertNil(phase.image)
        XCTAssertEqual(phase.error as? ImagePipelineError, .cacheMiss)
    }

    func testEnvironmentDefaultsToSharedPipeline() {
        XCTAssertTrue(EnvironmentValues().imagePipeline === ImagePipeline.shared)
    }

    @MainActor
    func testViewsCanBeConstructed() {
        let url = URL(string: "https://example.com/a.png")
        _ = PickelImage(url: url)
        _ = PickelImage(url: url, targetSize: CGSize(width: 40, height: 40), processors: [.circle]) { image in
            image.resizable()
        } placeholder: {
            ProgressView()
        }
        _ = PickelImage(url: url) { image in
            image.resizable()
        } placeholder: {
            ProgressView()
        } failure: {
            Image(systemName: "photo")
        }
        _ = PickelImage(request: nil) { phase in
            switch phase {
            case .empty: Color.clear
            case .success(let image): image
            case .failure: Image(systemName: "exclamationmark.triangle")
            }
        }
    }
}
