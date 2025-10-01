//
//  SampleHandler.swift
//  TextExtractorExtension
//
//  Created by Bogdan Mamaev on 21/9/2025.
//

import ReplayKit
import Vision

let sharedSuiteName = "group.com.bmamaev.ScreenTextExtractor"
let sharedDefaults = UserDefaults(suiteName: sharedSuiteName)
let sharedFileManager = FileManager.default

class SampleHandler: RPBroadcastSampleHandler {

    private var allTextData: [TextData] = []
    
    private var lastProcessTime = Date()
    private let processInterval: TimeInterval = 1.0 // 1 frame per second

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has started the broadcast.
        allTextData = [] // Reset data at the beginning of a new session
        print("Broadcast Started.")
    }

    override func broadcastPaused() {
        // User has paused the broadcast.
    }

    override func broadcastResumed() {
        // User has resumed the broadcast.
    }

    override func broadcastFinished() {

        // Clean and save the data to the shared App Group container
        let cleaner = DataCleaner()
        let cleanedData = cleaner.clean(rawData: allTextData)
        
        save(data: cleanedData)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {

        guard sampleBufferType == .video else { return }
        
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) > processInterval else {
            return
        }
        lastProcessTime = now
        
        // Convert the sample buffer to a CGImage
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        // Perform OCR on the image
        performOCR(on: cgImage) { [weak self] frameTextData in
            guard let self = self else { return }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            let timedData = frameTextData.map {
                TextData(timestamp: timestamp, text: $0.text, confidence: $0.confidence, boundingBox: $0.boundingBox)
            }
            self.allTextData.append(contentsOf: timedData)
        }
    }
    
    //Helper Functions
    
    private func performOCR(on image: CGImage, completion: @escaping ([(text: String, confidence: Float, boundingBox: CGRect)]) -> Void) {
        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                completion([])
                return
            }
            
            let textData = observations.compactMap { observation -> (String, Float, CGRect)? in
                guard let topCandidate = observation.topCandidates(1).first else { return nil }
                let transformedBox = observation.boundingBox.applying(CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1))
                return (topCandidate.string, topCandidate.confidence, transformedBox)
            }
            completion(textData)
        }
        
        request.recognitionLevel = .fast // Use .fast for real-time processing
        
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("Failed to perform OCR request: \(error)")
            completion([])
        }
    }
    
    private func save(data: [TextData]) {
        guard let containerURL = sharedFileManager.containerURL(forSecurityApplicationGroupIdentifier: sharedSuiteName) else {
            print("Error: Could not get shared container URL.")
            return
        }
        
        // Create the datasets subdirectory to match what ContentView expects
        let datasetsURL = containerURL.appendingPathComponent("datasets")
        
        do {
            // Ensure the datasets directory exists
            if !sharedFileManager.fileExists(atPath: datasetsURL.path) {
                try sharedFileManager.createDirectory(
                    at: datasetsURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
            
            let fileName = "ScreenTextDataset-\(Date().timeIntervalSince1970).json"
            let fileURL = datasetsURL.appendingPathComponent(fileName)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: fileURL)
            print("Dataset saved successfully to shared container: \(fileURL.path)")
        } catch {
            print("Error saving dataset to shared container: \(error)")
        }
    }
}
