# ``Pickel``

Download, cache and display images from the web in SwiftUI and UIKit.

@Metadata {
    @DisplayName("Pickel")
    @PageImage(purpose: icon, source: "pickel-icon", alt: "The Pickel icon")
}

## Overview

![The Pickel logo](pickel-logo.png)

Pickel is a lightweight, pure-Swift library for loading remote images in your app. Show an image with one line of code, and Pickel takes care of the rest:

- **Downloading**: images load in the background with async/await.
- **Caching**: images are kept in memory and on disk, so each one downloads only once.
- **Saving memory**: large images are shrunk to the size you display them at.
- **Placeholders and errors**: show a view while loading, and another if loading fails.

```swift
import Pickel

// SwiftUI
PickelImage(url: url) { image in
    image.resizable().scaledToFill()
} placeholder: {
    ProgressView()
}

// UIKit
imageView.pickel.setImage(with: url)
```

Pickel has no dependencies and supports iOS 17, macOS 14, tvOS 17 and visionOS 1 or later.

## Topics

### Essentials

- <doc:Installation>
- <doc:UsingPickelWithSwiftUI>
- <doc:UsingPickelWithUIKit>

### SwiftUI

- ``PickelImage``
- ``PickelImagePhase``

### UIKit

- ``PickelImageViewLoader``
- ``ImageTransition``

### Loading Images

- ``ImagePipeline``
- ``ImageRequest``
- ``ImagePrefetcher``

### Caching

- ``MemoryCache``
- ``DiskCache``

### Processing

- ``ImageProcessing``
- ``ImageProcessors``
- ``ImageContentMode``

### Networking

- ``ImageDownloading``
- ``ImageDownloader``

### Errors

- ``ImagePipelineError``
- ``ImageDownloaderError``
- ``ImageDecodingError``
- ``ImageProcessingError``
