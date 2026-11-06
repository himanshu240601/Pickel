//
//  SamplePhotos.swift
//  PickelDemo
//
//  Sample images from Unsplash (https://unsplash.com).
//

import Foundation

struct Photo: Identifiable, Hashable {
    let id: String
    let title: String

    /// A large version (1600px wide). Pickel downsamples it to whatever size
    /// it is displayed at, so even big images stay cheap in memory.
    var url: URL {
        URL(string: "https://images.unsplash.com/photo-\(id)?w=1600&q=80")!
    }
}

enum SamplePhotos {
    static let landscapes: [Photo] = [
        Photo(id: "1506744038136-46273834b3fb", title: "Valley"),
        Photo(id: "1501785888041-af3ef285b470", title: "Lake"),
        Photo(id: "1469474968028-56623f02e42e", title: "Sunrise"),
        Photo(id: "1470071459604-3b5ec3a7fe05", title: "Mist"),
        Photo(id: "1441974231531-c6227db76b6e", title: "Forest"),
        Photo(id: "1500530855697-b586d89ba3ee", title: "Road"),
        Photo(id: "1472214103451-9374bd1c798e", title: "Hills"),
        Photo(id: "1447752875215-b2761acb3c5d", title: "Woods"),
        Photo(id: "1433086966358-54859d0ed716", title: "Waterfall"),
        Photo(id: "1475924156734-496f6cac6ec1", title: "Coast"),
        Photo(id: "1426604966848-d7adac402bff", title: "Mountains"),
        Photo(id: "1465146344425-f00d5f5c8f07", title: "Meadow"),
        Photo(id: "1507525428034-b723cf961d3e", title: "Beach"),
        Photo(id: "1494500764479-0c8f2919a3d8", title: "Night sky"),
        Photo(id: "1518837695005-2083093ee35b", title: "Wave"),
        Photo(id: "1511300636408-a63a89df3482", title: "Pines"),
        Photo(id: "1500534314209-a25ddb2bd429", title: "Field"),
        Photo(id: "1519681393784-d120267933ba", title: "Stars")
    ]

    static let people: [Photo] = [
        Photo(id: "1534528741775-53994a69daeb", title: "Ava Thompson"),
        Photo(id: "1507003211169-0a1dd7228f2d", title: "Liam Carter"),
        Photo(id: "1494790108377-be9c29b29330", title: "Mia Rodriguez"),
        Photo(id: "1438761681033-6461ffad8d80", title: "Sofia Bennett")
    ]

    /// A URL that does not exist, to demonstrate failure handling.
    static let brokenURL = URL(string: "https://images.unsplash.com/photo-this-does-not-exist")!
}
