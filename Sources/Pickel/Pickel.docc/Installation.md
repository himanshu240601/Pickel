# Installation

Add Pickel to your app with Swift Package Manager.

## Requirements

| Platform | Minimum version |
|----------|-----------------|
| iOS      | 17.0            |
| macOS    | 14.0            |
| tvOS     | 17.0            |
| visionOS | 1.0             |

You need **Xcode 16** or later (Swift 6.0).

## Add the package in Xcode

1. In Xcode, choose **File → Add Package Dependencies…**
2. Paste the repository URL:

   ```
   https://github.com/himanshu240601/Pickel.git
   ```

3. Choose **Up to Next Major Version** starting from `1.0.0` and click **Add Package**.
4. Add the **Pickel** library to your app target.

## Add the package in Package.swift

If you're building a Swift package, add Pickel to your dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/himanshu240601/Pickel.git", from: "1.0.0")
]
```

Then add it to your target:

```swift
.target(
    name: "MyApp",
    dependencies: ["Pickel"]
)
```

## Import it

Add `import Pickel` to any file that loads images:

```swift
import Pickel
```

Next, show your first image with <doc:UsingPickelWithSwiftUI> or <doc:UsingPickelWithUIKit>.
