//
//  TextData.swift
//  ScreenTextExtractor
//
//  Created by Bogdan Mamaev on 21/9/2025.
//

import Foundation
import CoreGraphics

// Make it Codable for easy saving to JSON later.
// Make it Identifiable and Hashable for use in SwiftUI lists.
struct TextData: Codable, Identifiable, Hashable {
    let id = UUID() // Unique identifier for each piece of text
    let timestamp: TimeInterval
    let text: String
    let confidence: Float
    let boundingBox: CGRect
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case text
        case confidence
        case boundingBoxX, boundingBoxY, boundingBoxWidth, boundingBoxHeight
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(text, forKey: .text)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(boundingBox.origin.x, forKey: .boundingBoxX)
        try container.encode(boundingBox.origin.y, forKey: .boundingBoxY)
        try container.encode(boundingBox.width, forKey: .boundingBoxWidth)
        try container.encode(boundingBox.height, forKey: .boundingBoxHeight)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        text = try container.decode(String.self, forKey: .text)
        confidence = try container.decode(Float.self, forKey: .confidence)
        let x = try container.decode(CGFloat.self, forKey: .boundingBoxX)
        let y = try container.decode(CGFloat.self, forKey: .boundingBoxY)
        let width = try container.decode(CGFloat.self, forKey: .boundingBoxWidth)
        let height = try container.decode(CGFloat.self, forKey: .boundingBoxHeight)
        boundingBox = CGRect(x: x, y: y, width: width, height: height)
    }
    
    init(timestamp: TimeInterval, text: String, confidence: Float, boundingBox: CGRect) {
        self.timestamp = timestamp
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}
