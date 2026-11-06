//
//  UIImageView+Pickel.swift
//  Pickel
//

#if canImport(UIKit)
import UIKit

/// How a newly loaded image replaces the current one.
public enum ImageTransition: Sendable, Equatable {
    /// Swap instantly.
    case none
    /// Cross-dissolve over the given duration.
    case fade(TimeInterval)
}

extension UIImageView {
    /// Pickel image loading for this image view.
    ///
    /// ```swift
    /// imageView.pickel.setImage(with: url, placeholder: UIImage(named: "avatar"))
    /// ```
    public var pickel: PickelImageViewLoader {
        PickelImageViewLoader(base: self)
    }
}

/// Loads images into a `UIImageView`. Access through `imageView.pickel`.
///
/// Starting a new load cancels the previous one, which makes it safe to use
/// in reusable table and collection view cells.
@MainActor
public struct PickelImageViewLoader {
    let base: UIImageView

    /// Loads the image at `url` into the image view.
    ///
    /// - Parameters:
    ///   - placeholder: Shown while loading. When `nil`, the current image is
    ///     cleared.
    ///   - failureImage: Shown if loading fails. When `nil`, the placeholder
    ///     stays visible.
    ///   - processors: Processors applied after decoding.
    ///   - downsample: Downsample to the image view's current bounds (if it
    ///     has been laid out), using its `contentMode` and display scale.
    ///   - transition: Animation used when a loaded image is displayed.
    ///     Images from the memory cache are always shown without animation.
    ///   - pipeline: Pipeline used to load the image.
    ///   - completion: Called on the main actor with the result. Not called
    ///     when the load is cancelled.
    /// - Returns: The task performing the load, or `nil` if it completed
    ///   synchronously from the memory cache or `url` was `nil`.
    @discardableResult
    public func setImage(
        with url: URL?,
        placeholder: UIImage? = nil,
        failureImage: UIImage? = nil,
        processors: [any ImageProcessing] = [],
        downsample: Bool = true,
        transition: ImageTransition = .fade(0.2),
        pipeline: ImagePipeline = .shared,
        completion: (@MainActor (Result<UIImage, any Error>) -> Void)? = nil
    ) -> Task<Void, Never>? {
        let request = url.map { url in
            makeRequest(url: url, processors: processors, downsample: downsample)
        }

        return setImage(
            with: request,
            placeholder: placeholder,
            failureImage: failureImage,
            transition: transition,
            pipeline: pipeline,
            completion: completion
        )
    }

    /// Loads the image described by `request` into the image view. See the
    /// URL-based overload for parameter details. The request is used as-is
    /// (no automatic downsampling).
    @discardableResult
    public func setImage(
        with request: ImageRequest?,
        placeholder: UIImage? = nil,
        failureImage: UIImage? = nil,
        transition: ImageTransition = .fade(0.2),
        pipeline: ImagePipeline = .shared,
        completion: (@MainActor (Result<UIImage, any Error>) -> Void)? = nil
    ) -> Task<Void, Never>? {
        let state = loadState
        state.cancel()

        guard let request else {
            base.image = placeholder
            completion?(.failure(ImagePipelineError.missingURL))
            return nil
        }

        if !request.options.contains(.disableMemoryCacheReads),
           let cached = pipeline.cachedImage(for: request) {
            base.image = cached
            completion?(.success(cached))
            return nil
        }

        base.image = placeholder

        let id = UUID()
        let imageView = base

        let task = Task { @MainActor in
            let result: Result<UIImage, any Error>
            do {
                result = .success(try await pipeline.image(for: request))
            } catch {
                result = .failure(error)
            }

            guard !Task.isCancelled, state.id == id else {
                return
            }

            state.task = nil

            switch result {
            case .success(let image):
                Self.display(image, in: imageView, transition: transition)

            case .failure(let error):
                if error is CancellationError {
                    return
                }

                if let failureImage {
                    imageView.image = failureImage
                }
            }

            completion?(result)
        }

        state.id = id
        state.task = task
        return task
    }

    /// Cancels the current load, if any.
    public func cancel() {
        loadState.cancel()
    }

    // MARK: - Private

    private func makeRequest(
        url: URL,
        processors: [any ImageProcessing],
        downsample: Bool
    ) -> ImageRequest {
        let size = base.bounds.size
        let shouldDownsample = downsample && size.width > 0 && size.height > 0

        guard shouldDownsample else {
            return ImageRequest(url: url, processors: processors)
        }

        let contentMode: ImageContentMode = switch base.contentMode {
        case .scaleAspectFit: .aspectFit
        default: .aspectFill
        }

        return ImageRequest(
            url: url,
            targetSize: size,
            contentMode: contentMode,
            scale: base.traitCollection.displayScale,
            processors: processors
        )
    }

    private static func display(
        _ image: UIImage,
        in imageView: UIImageView,
        transition: ImageTransition
    ) {
        switch transition {
        case .fade(let duration) where duration > 0:
            UIView.transition(
                with: imageView,
                duration: duration,
                options: [.transitionCrossDissolve, .allowUserInteraction]
            ) {
                imageView.image = image
            }

        default:
            imageView.image = image
        }
    }

    private var loadState: LoadState {
        if let state = objc_getAssociatedObject(base, &loadStateKey) as? LoadState {
            return state
        }

        let state = LoadState()
        objc_setAssociatedObject(
            base,
            &loadStateKey,
            state,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return state
    }
}

nonisolated(unsafe) private var loadStateKey: UInt8 = 0

@MainActor
private final class LoadState {
    var id: UUID?
    var task: Task<Void, Never>?

    func cancel() {
        task?.cancel()
        task = nil
        id = nil
    }

    deinit {
        task?.cancel()
    }
}
#endif
