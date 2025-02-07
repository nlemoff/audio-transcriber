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
        
        SpeechTranscriptionService.shared.sendAudio(
            fileURL: audioURL,
            onTranscript: { speaker, text in
                print("Received transcript segment for: \(audioURL.path)")
                DispatchQueue.main.async {
                    transcriptSegments.append(TranscriptSegment(speaker: speaker, text: text))
                }
            },
            onComplete: {
                print("Transcription complete callback received for: \(audioURL.path)")
                DispatchQueue.main.async {
                    transcribedFiles.insert(audioURL.path)
                    isTranscribing = false
                    currentTranscriptionPath = nil
                    print("File marked as transcribed: \(audioURL.path)")
                }
            },
            onError: { error in
                print("Transcription error occurred for: \(audioURL.path)")
                DispatchQueue.main.async {
                    isTranscribing = false
                    currentTranscriptionPath = nil
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
                Button {
                    if audioRecorder.isRecording {
                        audioRecorder.stopRecording()
                    } else {
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
        .onChange(of: audioRecorder.audioFileURL) { newURL in
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
