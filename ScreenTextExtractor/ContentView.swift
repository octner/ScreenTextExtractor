import SwiftUI
import ReplayKit

struct ContentView: View {
    @State private var datasets: [URL] = []
    @State private var isBroadcasting = RPScreenRecorder.shared().isRecording
    @State private var itemToShare: ShareableFileProvider?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let sharedSuiteName = "group.com.bmamaev.ScreenTextExtractor"
    let textStitcher = TextStitcher()
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Screen Text Extractor")
                    .font(.largeTitle)
                    .padding()
                
                Text("To record, open Control Center, long-press the screen record button, and select 'ScreenTextExtractor'.")
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button(action: loadDatasets) {
                    Label("Load Datasets", systemImage: "arrow.clockwise")
                }
                .padding()
                
                if datasets.isEmpty {
                    Text("No datasets found")
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(datasets, id: \.self) { url in
                            DatasetRow(
                                url: url,
                                onShareJson: { urlToShare in
                                    shareJson(from: urlToShare) // Call the JSON share function
                                },
                                onShareText: { urlToShare in
                                    shareText(from: urlToShare) // Call the new Text share function
                                }
                            )
                        }
                        .onDelete(perform: deleteDataset)
                    }
                }
            }
            .onAppear(perform: loadDatasets)
            .navigationTitle("Datasets")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadDatasets) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(item: $itemToShare, onDismiss: cleanupTemporaryFile) { provider in
                ShareSheet(
                    items: [provider],
                    excludedActivityTypes: [.assignToContact, .saveToCameraRoll],
                    onComplete: { completed in
                        if completed {
                            print("File shared successfully")
                        }
                    }
                )
            }
        }
    }
    
    private func shareJson(from url: URL) {
        if let tempURL = createTemporaryCopy(of: url) {
            self.itemToShare = ShareableFileProvider(fileURL: tempURL)
        } else {
            errorMessage = "Failed to prepare JSON file for sharing"
            showingError = true
        }
    }
    
    private func shareText(from jsonURL: URL) {
        do {
            // 1. Read the JSON data from the original file
            let jsonData = try Data(contentsOf: jsonURL)
            
            // 2. Decode the JSON back into our [TextData] array
            let decodedData = try JSONDecoder().decode([TextData].self, from: jsonData)
            
            // 3. Use the stitcher to create the final text string
            let stitchedText = textStitcher.stitch(data: decodedData)
            
            // 4. Save this string to a temporary .txt file
            let tempDirectoryURL = FileManager.default.temporaryDirectory
            let uniqueFilename = jsonURL.deletingPathExtension().lastPathComponent + ".txt"
            let tempTxtURL = tempDirectoryURL.appendingPathComponent(uniqueFilename)
            
            try stitchedText.write(to: tempTxtURL, atomically: true, encoding: .utf8)
            
            // 5. Share the temporary .txt file
            self.itemToShare = ShareableFileProvider(fileURL: tempTxtURL)
            
        } catch {
            errorMessage = "Failed to convert JSON to Text: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func cleanupTemporaryFile() {
        guard let provider = itemToShare else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                try FileManager.default.removeItem(at: provider.fileURL)
                print("Cleaned up temporary file: \(provider.fileURL.lastPathComponent)")
            } catch {
                print("Warning: Could not clean up temporary file: \(error.localizedDescription)")
            }
        }
    }
    
    private func createTemporaryCopy(of originalURL: URL) -> URL? {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
        let uniqueFilename = "\(UUID().uuidString)-\(originalURL.lastPathComponent)"
        let destinationURL = tempDirectoryURL.appendingPathComponent(uniqueFilename)
        
        do {
            // Ensure we start fresh
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy the file
            try FileManager.default.copyItem(at: originalURL, to: destinationURL)
            
            // Verify the file exists and is readable
            guard FileManager.default.isReadableFile(atPath: destinationURL.path) else {
                print("Error: Temporary file is not readable")
                return nil
            }
            
            print("Created temporary copy at: \(destinationURL.path)")
            return destinationURL
            
        } catch {
            print("Error creating temporary copy: \(error.localizedDescription)")
            return nil
        }
    }
    
    func loadDatasets() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: sharedSuiteName
        ) else {
            print("Error: Could not get shared container URL.")
            self.datasets = []
            return
        }
        
        let datasetsURL = containerURL.appendingPathComponent("datasets")
        
        do {
            // Create directory if needed
            if !FileManager.default.fileExists(atPath: datasetsURL.path) {
                try FileManager.default.createDirectory(
                    at: datasetsURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
            
            // Load files
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: datasetsURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
            )
            
            // Filter and sort JSON files by modification date (newest first)
            self.datasets = fileURLs
                .filter { $0.pathExtension == "json" }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                    return date1 > date2
                }
            
        } catch {
            print("Error loading datasets: \(error.localizedDescription)")
            self.datasets = []
        }
    }
    
    func deleteDataset(at offsets: IndexSet) {
        for index in offsets {
            let url = datasets[index]
            do {
                try FileManager.default.removeItem(at: url)
                print("Deleted: \(url.lastPathComponent)")
            } catch {
                print("Error deleting file: \(error.localizedDescription)")
            }
        }
        loadDatasets()
    }
}

// In ContentView.swift

struct DatasetRow: View {
    let url: URL
    let onShareJson: (URL) -> Void
    let onShareText: (URL) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                
                if let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Share as Text Button
            Button(action: { onShareText(url) }) {
                Image(systemName: "doc.text")
                    .font(.title3)
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Share as Plain Text")

            // Share as JSON Button
            Button(action: { onShareJson(url) }) {
                Image(systemName: "curlybraces")
                    .font(.title3)
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.leading, 8)
            .help("Share as JSON Data")
        }
        .padding(.vertical, 4)
    }
}
