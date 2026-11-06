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

### UIKit

```swift
import Pickel

imageView.pickel.setImage(with: url)
```

This works in table and collection view cells too: when a cell is reused, the old load is cancelled automatically.

### async/await

```swift
let image = try await ImagePipeline.shared.image(for: url)
```

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
