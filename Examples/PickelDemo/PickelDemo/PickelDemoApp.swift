//
//  PickelDemoApp.swift
//  PickelDemo
//
//  A small app showing the main ways to use Pickel.
//

import SwiftUI

@main
struct PickelDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            GalleryView()
                .tabItem { Label("Gallery", systemImage: "square.grid.3x3") }

            AvatarsView()
                .tabItem { Label("Avatars", systemImage: "person.crop.circle") }

            UIKitGalleryView()
                .tabItem { Label("UIKit", systemImage: "rectangle.stack") }

            MoreExamplesView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
    }
}
