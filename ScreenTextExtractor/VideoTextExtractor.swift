//
//  VideoTextExtractor.swift
//  ScreenTextExtractor
//
//  Created by Bogdan Mamaev on 21/9/2025.
//

import Foundation
import AVFoundation
import Vision
import UIKit

class VideoTextExtractor {
    
    // MARK: - Public Method
    
    func processVideo(url: URL, completion: @escaping ([TextData]) -> Void) {
        // We use a Task to create an async context to load the duration.
        Task {
            let asset = AVAsset(url: url)
            
            // Asynchronously load the duration of the video
            let videoDuration: TimeInterval
            do {
                let duration = try await asset.load(.duration)
                videoDuration = duration.seconds
            } catch {
                print("Failed to load video duration: \(error)")
                completion([]) // Return empty if we can't get the duration
                return
            }
            
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            var allTextData: [TextData] = []
            
            let sampleRate: Double = 2.0
            let totalFramesToProcess = Int(videoDuration * sampleRate)
            
            let frameTimes = (0..<totalFramesToProcess).map {
                CMTime(seconds: Double($0) / sampleRate, preferredTimescale: 600)
            }
            
            let dispatchGroup = DispatchGroup()

            imageGenerator.generateCGImagesAsynchronously(forTimes: frameTimes.map { NSValue(time: $0) }) { requestedTime, cgImage, actualTime, result, error in
                
                dispatchGroup.enter()
                
                guard let cgImage = cgImage, error == nil else {
                    print("Error generating image at time \(requestedTime.seconds): \(error?.localizedDescription ?? "unknown error")")
                    dispatchGroup.leave()
                    return
                }
                
                self.performOCR(on: cgImage) { frameTextData in
                    let timedData = frameTextData.map {
                        TextData(timestamp: actualTime.seconds, text: $0.text, confidence: $0.confidence, boundingBox: $0.boundingBox)
                    }
                    allTextData.append(contentsOf: timedData)
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                print("Video processing complete. Found \(allTextData.count) total text items.")
                // Sort the final data by timestamp before returning.
                completion(allTextData.sorted(by: { $0.timestamp < $1.timestamp }))
            }
        }
    }
    
    // MARK: - Private Helper Method
    
    // It's a helper for the processVideo function.
    private func performOCR(on image: CGImage, completion: @escaping ([(text: String, confidence: Float, boundingBox: CGRect)]) -> Void) {
        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                completion([])
                return
            }
            
            let textData = observations.compactMap { observation -> (String, Float, CGRect)? in
                guard let topCandidate = observation.topCandidates(1).first else { return nil }
                
                // Convert Vision's bottom-left origin coordinate system to a top-left origin system.
                let transformedBox = observation.boundingBox.applying(CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1))
                
                return (topCandidate.string, topCandidate.confidence, transformedBox)
            }
            completion(textData)
        }
        
        request.recognitionLevel = .accurate
        
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("Failed to perform OCR request: \(error)")
                completion([])
            }
        }
    }
    
}
