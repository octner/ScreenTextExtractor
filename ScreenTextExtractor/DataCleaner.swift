//
//  DataCleaner.swift
//  ScreenTextExtractor
//
//  Created by Bogdan Mamaev on 21/9/2025.
//

import Foundation

class DataCleaner {
    
    /// Cleans the raw text data by removing duplicates that appear in consecutive frames.
    /// This method identifies only the new text that appears at each timestamp.

    func clean(rawData: [TextData]) -> [TextData] {
        guard !rawData.isEmpty else { return [] }
        
        var cleanedData: [TextData] = []
        
        // Group all text data by its exact timestamp.
        let groupedByTime = Dictionary(grouping: rawData, by: { $0.timestamp })
        
        // Get all unique timestamps and sort them chronologically.
        let sortedTimestamps = groupedByTime.keys.sorted()
        
        var previousFrameTextSet = Set<String>()
        
        for timestamp in sortedTimestamps {
            guard let currentFrameData = groupedByTime[timestamp] else { continue }
            let currentFrameTextSet = Set(currentFrameData.map { $0.text })
            
            // Find the text that is in the current frame but was NOT in the previous one.
            let newTexts = currentFrameTextSet.subtracting(previousFrameTextSet)
            
            if !newTexts.isEmpty {
                // Find the original TextData objects that correspond to these new texts.
                let newTextDataObjects = currentFrameData.filter { newTexts.contains($0.text) }
                cleanedData.append(contentsOf: newTextDataObjects)
            }
            
            // The current frame becomes the previous frame for the next iteration.
            previousFrameTextSet = currentFrameTextSet
        }
        
        return cleanedData
    }
}
