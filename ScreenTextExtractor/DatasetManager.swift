//
//  DatasetManager.swift
//  ScreenTextExtractor
//
//  Created by Bogdan Mamaev on 21/9/2025.
//

import Foundation

class DatasetManager {
    
    /// Encodes the data to JSON and saves it to the app's Documents directory.

    func save(data: [TextData]) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let jsonData = try encoder.encode(data)
            
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Error: Could not find documents directory.")
                return nil
            }
            
            let fileName = "ScreenTextDataset-\(Date().timeIntervalSince1970).json"
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            
            try jsonData.write(to: fileURL)
            
            print("Dataset saved successfully to: \(fileURL.path)")
            return fileURL
            
        } catch {
            print("Error saving dataset: \(error)")
            return nil
        }
    }
}
