//
//  ContentView.swift
//  MicAudioRecorder
//
//  Created by Nicholas Lemoff on 2/6/25.
//

import SwiftUI
import AppKit

struct TranscriptSegment: Identifiable {
    let id = UUID()
    let speaker: String
    let text: String
}

struct ContentView: View {
    @StateObject var audioRecorder = AudioRecorder()
    @State private var transcriptSegments: [TranscriptSegment] = []
    @State private var isTranscribing = false
    @State private var transcribedFiles: Set<String> = []
    @State private var currentTranscriptionPath: String? = nil
    @State private var showingDriverAlert = false
    
    private var canTranscribe: Bool {
        guard let currentURL = audioRecorder.audioFileURL else { return false }
        return !audioRecorder.isRecording && 
               !isTranscribing && 
               !transcribedFiles.contains(currentURL.path) &&
               currentTranscriptionPath != currentURL.path
    }
    
    private func handleTranscription() {
        guard let audioURL = audioRecorder.audioFileURL,
              FileManager.default.fileExists(atPath: audioURL.path),
              !transcribedFiles.contains(audioURL.path) else {
            print("Cannot transcribe: File already transcribed or invalid")
            return
        }
        
        isTranscribing = true
        currentTranscriptionPath = audioURL.path
        print("Starting transcription of file: \(audioURL.path)")
        
        // Clear previous transcripts for this file
        if transcriptSegments.isEmpty {
            transcriptSegments = []
        }
        
        SpeechTranscriptionService.shared.sendAudio(
            fileURL: audioURL,
            onTranscript: { speaker, text in
                print("Received transcript segment: \(speaker) - \(text)")
                DispatchQueue.main.async {
                    // Check if this is a new segment or continuation
                    if let lastSegment = transcriptSegments.last,
                       lastSegment.speaker == speaker {
                        // Update the last segment
                        transcriptSegments.removeLast()
                        transcriptSegments.append(TranscriptSegment(
                            speaker: speaker,
                            text: lastSegment.text + " " + text
                        ))
                    } else {
                        // Add new segment
                        transcriptSegments.append(TranscriptSegment(
                            speaker: speaker,
                            text: text
                        ))
                    }
                }
            },
            onComplete: {
                print("Transcription complete callback received for: \(audioURL.path)")
                DispatchQueue.main.async {
                    transcribedFiles.insert(audioURL.path)
                    isTranscribing = false
                    currentTranscriptionPath = nil
                    print("File marked as transcribed: \(audioURL.path)")
                    
                    // If no transcripts were received, add an error message
                    if transcriptSegments.isEmpty {
                        transcriptSegments.append(TranscriptSegment(
                            speaker: "System",
                            text: "No speech detected in the recording."
                        ))
                    }
                }
            },
            onError: { error in
                print("Transcription error occurred for: \(audioURL.path)")
                DispatchQueue.main.async {
                    isTranscribing = false
                    currentTranscriptionPath = nil
                    
                    // Add error message to transcript
                    transcriptSegments.append(TranscriptSegment(
                        speaker: "Error",
                        text: "Transcription failed: \(error.localizedDescription)"
                    ))
                    
                    print("Transcription error: \(error.localizedDescription)")
                }
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Mic Audio Recorder")
                .font(.title)
            
            if !audioRecorder.permissionGranted {
                VStack {
                    Text("Microphone access is required")
                        .foregroundColor(.red)
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            } else {
                if !audioRecorder.isBlackHoleInstalled {
                    VStack(spacing: 10) {
                        Text("System Audio Recording")
                            .font(.headline)
                        Text("To record both system audio and microphone:")
                            .font(.subheadline)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("1. Install BlackHole audio driver")
                            Text("2. Open System Settings > Sound")
                            Text("3. Create Multi-Output Device with:")
                                .padding(.bottom, 2)
                            Text("   • Your Speakers")
                                .padding(.leading)
                            Text("   • BlackHole 2ch")
                                .padding(.leading)
                            Text("4. Set Multi-Output as default output")
                            Text("5. Set BlackHole 2ch as default input")
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)
                        
                        Button("Install BlackHole") {
                            audioRecorder.openBlackHoleInstallPage()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Open Sound Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(nsColor: .windowBackgroundColor))
                    .cornerRadius(10)
                }
                
                Button {
                    if audioRecorder.isRecording {
                        print("Stop button pressed")
                        audioRecorder.stopRecording()
                    } else {
                        print("Record button pressed")
                        audioRecorder.startRecording()
                    }
                } label: {
                    Text(audioRecorder.isRecording ? "Stop Recording" : "Record")
                        .frame(minWidth: 100)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(audioRecorder.isRecording ? .red : .blue)
                
                Button {
                    handleTranscription()
                } label: {
                    if isTranscribing {
                        Text("Transcribing...")
                    } else if let currentURL = audioRecorder.audioFileURL,
                              transcribedFiles.contains(currentURL.path) {
                        Text("Transcribed")
                    } else {
                        Text("Transcribe")
                    }
                }
                .frame(minWidth: 100)
                .padding()
                .buttonStyle(.borderedProminent)
                .tint(isTranscribing ? .gray : (canTranscribe ? .green : .gray))
                .disabled(!canTranscribe)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(transcriptSegments) { segment in
                        VStack(alignment: .leading) {
                            Text(segment.speaker)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(segment.text)
                                .padding(.leading)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 2)
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 600)
        .onChange(of: audioRecorder.audioFileURL) { _, newURL in
            if let url = newURL {
                print("New recording detected at: \(url.path)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
