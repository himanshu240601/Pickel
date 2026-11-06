//
//  AvatarsView.swift
//  PickelDemo
//
//  SwiftUI: circular avatars using a processor.
//

import Pickel
import SwiftUI

struct AvatarsView: View {
    var body: some View {
        NavigationStack {
            List(SamplePhotos.people) { person in
                HStack(spacing: 16) {
                    // `.circle` crops the image into a circle once, off the main
                    // thread, and caches the result.
                    PickelImage(
                        url: person.url,
                        targetSize: CGSize(width: 56, height: 56),
                        processors: [.circle]
                    ) { image in
                        image.resizable()
                    } placeholder: {
                        Circle().fill(.quaternary)
                    } failure: {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 56, height: 56)

                    Text(person.title)
                        .font(.headline)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Avatars")
        }
    }
}
