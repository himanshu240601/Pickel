# Using Pickel with SwiftUI

Show remote images with the `PickelImage` view.

## Show an image

Pass a URL and describe how to display the image and what to show while it loads:

```swift
import Pickel
import SwiftUI

struct PhotoView: View {
    let url: URL?

    var body: some View {
        PickelImage(url: url) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ProgressView()
        }
        .frame(width: 200, height: 200)
        .clipped()
    }
}
```

If the image is already cached, it appears immediately and the placeholder is skipped. If the view disappears before the image arrives, loading is cancelled.

## Show a view when loading fails

Add a `failure` view. If you leave it out, the placeholder stays visible when loading fails.

```swift
PickelImage(url: url) { image in
    image.resizable().scaledToFill()
} placeholder: {
    ProgressView()
} failure: {
    Image(systemName: "photo")
}
```

## Handle every state yourself

For full control, for example to show the error or a retry button, switch over the ``PickelImagePhase``:

```swift
PickelImage(url: url) { phase in
    switch phase {
    case .empty:
        ProgressView()
    case .success(let image):
        image.resizable().scaledToFit()
    case .failure(let error):
        Text(error.localizedDescription)
    }
}
```

## Save memory with large images

Pass the size the image is displayed at. Pickel shrinks the image to that size while loading, which uses far less memory in grids and lists:

```swift
PickelImage(url: url, targetSize: CGSize(width: 100, height: 100)) { image in
    image.resizable().scaledToFill()
} placeholder: {
    Color.gray.opacity(0.2)
}
.frame(width: 100, height: 100)
.clipped()
```

## Make round images

Use a processor to round the corners or crop the image to a circle:

```swift
PickelImage(url: avatarURL, targetSize: CGSize(width: 48, height: 48), processors: [.circle]) { image in
    image.resizable()
} placeholder: {
    Circle().fill(.gray.opacity(0.2))
}
.frame(width: 48, height: 48)
```

Other built-in processors are `.roundedCorners(radius:)` and `.resize(size:contentMode:crop:upscale:)`.

## Load an image yourself

When you need the image itself rather than a view, use ``ImagePipeline``:

```swift
let image = try await ImagePipeline.shared.image(for: url)
```

## See also

- <doc:UsingPickelWithUIKit>
- ``PickelImage``
- ``ImagePipeline``
