//
//  ShareableFileProvider.swift
//  ScreenTextExtractor
//
//  Created by Bogdan Mamaev on 21/9/2025.
//

import UIKit
import LinkPresentation
import UniformTypeIdentifiers

class ShareableFileProvider: NSObject, UIActivityItemSource, Identifiable {
    
    let fileURL: URL
    let id = UUID()
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init()
    }
    
    // MARK: - UIActivityItemSource
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return fileURL
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return fileURL
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "Screen Recording Data - \(fileURL.lastPathComponent)"
    }
    
    // --- THIS IS THE KEY CHANGE ---
    // Make the data type identifier DYNAMIC based on the file extension.
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        if fileURL.pathExtension.lowercased() == "json" {
            return UTType.json.identifier
        } else if fileURL.pathExtension.lowercased() == "txt" {
            return UTType.plainText.identifier
        }
        // Fallback for any other type
        return UTType.data.identifier
    }
    
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = fileURL
        
        // --- ANOTHER DYNAMIC CHANGE ---
        // Choose an icon based on the file type
        let systemIconName: String
        if fileURL.pathExtension.lowercased() == "json" {
            systemIconName = "curlybraces.square"
        } else {
            systemIconName = "doc.text"
        }
        
        if let image = UIImage(systemName: systemIconName) {
            metadata.iconProvider = NSItemProvider(object: image)
        }
        
        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let fileSize = attributes[.size] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let sizeString = formatter.string(fromByteCount: fileSize)
            metadata.title = "\(fileURL.lastPathComponent) (\(sizeString))"
        } else {
            metadata.title = fileURL.lastPathComponent
        }
        
        return metadata
    }
}
