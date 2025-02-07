//
//  SpeechTranscriptionService.swift
//  MicAudioRecorder
//
//  Created by Nicholas Lemoff on 2/6/25.
//

import Foundation

class SpeechTranscriptionService {
    static let shared = SpeechTranscriptionService()
    
    // Use IP address instead of localhost
    let backendURL = URL(string: "http://127.0.0.1:8000/transcribe")!
    
    func sendAudio(fileURL: URL, onTranscript: @escaping (String, String) -> Void, onComplete: @escaping () -> Void, onError: @escaping (Error) -> Void) {
        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30 // Increase timeout to 30 seconds
        
        // Generate a unique boundary string using a UUID
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")
        
        // Create the multipart form body with the audio file
        let httpBody = createBody(fileURL: fileURL, boundary: boundary)
        request.httpBody = httpBody
        
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true // Wait for network connectivity
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network Error: \(error.localizedDescription)")
                onError(error)
                return
            }
            
            // Check if we have a valid HTTP response and it's successful (2xx status code)
            if let httpResponse = response as? HTTPURLResponse {
                print("Server responded with status code: \(httpResponse.statusCode)")
                if !(200...299).contains(httpResponse.statusCode) {
                    onError(NSError(domain: "", code: httpResponse.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"]))
                    return
                }
            }
            
            guard let data = data else {
                print("No data received from server")
                onError(NSError(domain: "", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "No data received from server"]))
                return
            }
            
            let events = String(data: data, encoding: .utf8)?.components(separatedBy: "\n\n") ?? []
            print("Processing \(events.count) events")
            
            var hasCompletionEvent = false
            
            for event in events {
                guard event.hasPrefix("data: ") else { continue }
                
                let jsonString = String(event.dropFirst(6))
                guard let jsonData = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    continue
                }
                
                if let complete = json["complete"] as? Bool, complete {
                    hasCompletionEvent = true
                } else if let speaker = json["speaker"] as? String,
                          let text = json["text"] as? String {
                    print("Processing transcript: \(speaker) - \(text)")
                    onTranscript(speaker, text)
                }
            }
            
            if hasCompletionEvent {
                print("Completion event received")
                onComplete()
            } else {
                print("No completion event found in response")
                onComplete()  // Still complete to avoid stuck state
            }
        }
        task.resume()
    }
    
    private func createBody(fileURL: URL, boundary: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        let filename = fileURL.lastPathComponent
        let mimeType = "audio/wav"  // Changed to wav since we're using wav files
        
        print("Creating request body with file: \(filename)")
        
        // Append the file data to the multipart body
        body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        body.append(
          "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\(lineBreak)"
            .data(using: .utf8)!
        )
        body.append("Content-Type: \(mimeType)\(lineBreak + lineBreak)"
                        .data(using: .utf8)!)
        
        if let fileData = try? Data(contentsOf: fileURL) {
            print("Successfully read file data of size: \(fileData.count) bytes")
            body.append(fileData)
        } else {
            print("Failed to read file data from: \(fileURL)")
        }
        
        body.append(lineBreak.data(using: .utf8)!)
        body.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        
        return body
    }
}
