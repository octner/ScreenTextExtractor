//
//  TextStitcher.swift
//  ScreenTextExtractor
//
//  Created by Bogdan Mamaev on 21/9/2025.
//

import Foundation

class TextStitcher {
    
    /// Stitches an array of TextData objects into a single, coherent string.
    func stitch(data: [TextData]) -> String {
        guard !data.isEmpty else { return "" }
        
        // Group all text data by its exact timestamp.
        let groupedByTime = Dictionary(grouping: data, by: { $0.timestamp })
        
        // Get all unique timestamps and sort them chronologically.
        let sortedTimestamps = groupedByTime.keys.sorted()
        
        var stitchedTextBlocks: [String] = []
        
        for timestamp in sortedTimestamps {
            guard let frameData = groupedByTime[timestamp] else { continue }
            
            // For each frame, sort the text fragments from top-to-bottom, then left-to-right.
            let sortedFrameText = frameData.sorted {
                if abs($0.boundingBox.origin.y - $1.boundingBox.origin.y) < 0.01 {
                    // If they are on the same line (Y is similar), sort by X.
                    return $0.boundingBox.origin.x < $1.boundingBox.origin.x
                }
                // Otherwise, sort by Y (top-to-bottom).
                return $0.boundingBox.origin.y < $1.boundingBox.origin.y
            }
            .map { $0.text }
            .joined(separator: " ") // Join fragments from the same frame with a space.
            
            stitchedTextBlocks.append(sortedFrameText)
        }
        
        return stitchedTextBlocks.joined(separator: "\n\n")
    }
}
