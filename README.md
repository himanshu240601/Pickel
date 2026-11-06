# Pickel

**Images, without the pickle.**

Pickel loads images from the internet and shows them in your iOS app. Images are cached, so each one downloads only once.

- Works with **SwiftUI** and **UIKit**
- Caches images in memory and on disk
- Lightweight, with no dependencies

## Installation

In Xcode, go to **File → Add Package Dependencies…** and paste:

```
https://github.com/himanshu240601/Pickel.git
```

Or in `Package.swift`:

```swift
.package(url: "https://github.com/himanshu240601/Pickel.git", from: "1.0.0")
```

Requires iOS 17+ and Xcode 16+. macOS 14+, tvOS 17+ and visionOS 1+ are also supported.

## Usage

### SwiftUI

```swift
import Pickel

PickelImage(url: url) { image in
    image.resizable().scaledToFill()
} placeholder: {
    ProgressView()
}
.frame(width: 100, height: 100)
```

**Placeholder and failure views:**

```swift
PickelImage(url: url) { image in
    image.resizable().scaledToFill()
} placeholder: {
    ProgressView()                  // shown while loading
} failure: {
    Image(systemName: "photo")      // shown if loading fails
}
```

- If you leave out `failure`, the placeholder stays visible when loading fails.
- If the image is already cached, it shows instantly and the placeholder is skipped.
- To use the error itself, for example to show a retry button, use the phase-based version:

```swift
PickelImage(url: url) { phase in
    switch phase {
    case .empty:              ProgressView()
    case .success(let image): image.resizable()
    case .failure(let error): Text(error.localizedDescription)
    }
}
```

### UIKit

```swift
import Pickel

imageView.pickel.setImage(with: url)
```

This works in table and collection view cells too: when a cell is reused, the old load is cancelled automatically.

**Placeholder and failure images:**

```swift
imageView.pickel.setImage(
    with: url,
    placeholder: UIImage(named: "placeholder"), // shown while loading
    failureImage: UIImage(named: "broken")      // shown if loading fails (optional)
)
```

- The placeholder appears right away, then fades into the real image when it arrives.
- If the image is already cached, it shows instantly and the placeholder is skipped.
- If loading fails and you didn't pass a `failureImage`, the placeholder stays.
- With no placeholder, the image view is cleared while loading, so a reused cell never shows the previous row's image.
- The placeholder uses the image view's `contentMode`, so pick one that suits both, for example `.scaleAspectFill` for photos.

### async/await

```swift
let image = try await ImagePipeline.shared.image(for: url)
```

## Sample app

A demo app is included in [`Examples/PickelDemo`](Examples/PickelDemo). Open `Examples/PickelDemo/PickelDemo.xcodeproj` in Xcode and press Run. It shows:

- **Gallery**: a SwiftUI grid with placeholder and failure views
- **Avatars**: circular images using the `.circle` processor
- **UIKit**: a collection view with `imageView.pickel.setImage(with:)` and prefetching
- **More**: processors, error handling with retry, async/await, and clearing the cache

The sample uses photos from [Unsplash](https://unsplash.com).

## Tips

**Large images:** to save memory, pass the size the image will be shown at. Pickel shrinks the image to that size:

```swift
PickelImage(url: url, targetSize: CGSize(width: 100, height: 100)) { image in
    image.resizable()
} placeholder: {
    Color.gray
}
```

(UIKit does this for you automatically, using the image view's size.)

**Round images:**

```swift
PickelImage(url: url, processors: [.circle]) { ... }
imageView.pickel.setImage(with: url, processors: [.roundedCorners(radius: 12)])
```

**Clearing the cache:**

```swift
await ImagePipeline.shared.removeAllCachedImages()
```

## Learn more

Every public type includes documentation comments. In Xcode, Option-click a type to read them. Good places to start:

- `ImageRequest`: custom headers, cache options, sizes
- `ImagePipeline.Configuration`: cache size limits, custom networking
- `ImagePrefetcher`: start loading images before they scroll into view

## License

MIT. See [LICENSE](LICENSE).
