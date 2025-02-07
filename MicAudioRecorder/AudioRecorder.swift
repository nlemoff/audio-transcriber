//
//  AudioRecorder.swift
//  MicAudioRecorder
//
//  Created by Nicholas Lemoff on 2/6/25.
//

import Foundation
import AVFoundation
import AppKit

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var permissionGranted = false
    private var audioRecorder: AVAudioRecorder?
    @Published var audioFileURL: URL?
    private var recordingCount = 0
    private let fileManager = FileManager.default
    private var recordingsDirectory: URL?
    
    override init() {
        super.init()
        setupRecordingsDirectory()
        requestMicrophoneAccess()
    }
    
    private func setupRecordingsDirectory() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        
        do {
            try fileManager.createDirectory(at: recordingsPath, withIntermediateDirectories: true, attributes: nil)
            recordingsDirectory = recordingsPath
            print("Recordings directory set up at: \(recordingsPath.path)")
        } catch {
            print("Error setting up recordings directory: \(error)")
        }
    }
    
    private func requestMicrophoneAccess() {
        // Ensure we're on the main thread for UI operations
        DispatchQueue.main.async {
            // Debug info about bundle and Info.plist
            print("Bundle identifier: \(Bundle.main.bundleIdentifier ?? "none")")
            print("Info.plist path: \(Bundle.main.url(forResource: "Info", withExtension: "plist")?.path ?? "not found")")
            print("All Info.plist keys: \(Bundle.main.infoDictionary?.keys.joined(separator: ", ") ?? "none")")
            
            // Check for usage description
            if let usageDescription = Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") as? String {
                print("Found usage description: \(usageDescription)")
            } else {
                print("ERROR: NSMicrophoneUsageDescription not found in Info.plist")
                self.permissionGranted = false
                return
            }
            
            // Check current authorization status
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                print("Microphone access already authorized")
                self.permissionGranted = true
            case .notDetermined:
                print("Requesting microphone access...")
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                    DispatchQueue.main.async {
                        self?.permissionGranted = granted
                        print("Microphone access \(granted ? "granted" : "denied")")
                    }
                }
            case .denied:
                print("Microphone access denied")
                self.permissionGranted = false
                // Prompt user to change privacy settings
                let alert = NSAlert()
                alert.messageText = "Microphone Access Required"
                alert.informativeText = "This app requires microphone access to record audio. Please enable it in System Settings."
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Cancel")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                        NSWorkspace.shared.open(url)
                    }
                }
            case .restricted:
                print("Microphone access restricted")
                self.permissionGranted = false
            @unknown default:
                print("Unknown authorization status")
                self.permissionGranted = false
            }
        }
    }
    
    func startRecording() {
        guard permissionGranted else {
            print("Cannot start recording - microphone access not granted")
            requestMicrophoneAccess()
            return
        }
        
        // Define the recording settings for macOS
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        guard let recordingsDirectory = recordingsDirectory else {
            print("Recordings directory not set up")
            return
        }
        
        // Create a unique filename for this recording
        recordingCount += 1
        let fileName = "recording_\(Int(Date().timeIntervalSince1970))_\(recordingCount).wav"
        let url = recordingsDirectory.appendingPathComponent(fileName)
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            
            if audioRecorder?.prepareToRecord() ?? false {
                audioRecorder?.record()
                isRecording = true
                audioFileURL = url
                print("Recording started at: \(url.path)")
            } else {
                print("Error: Could not prepare the recorder.")
            }
        } catch {
            print("Error setting up recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        print("Recording stopped.")
        
        // Verify the recording
        if let url = audioFileURL {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? UInt64 ?? 0
                print("Recorded file size: \(fileSize) bytes")
                
                if fileManager.fileExists(atPath: url.path),
                   fileManager.isReadableFile(atPath: url.path) {
                    print("Audio file is valid and readable at: \(url.path)")
                    // Ensure the UI updates by reassigning the URL
                    DispatchQueue.main.async {
                        let currentURL = self.audioFileURL
                        self.audioFileURL = nil
                        self.audioFileURL = currentURL
                    }
                } else {
                    print("Warning: Audio file may not be valid or readable")
                    audioFileURL = nil
                }
            } catch {
                print("Error verifying recording: \(error)")
                audioFileURL = nil
            }
        }
    }
    
    // Clean up old recordings except the most recent one
    private func cleanupOldRecordings() {
        guard let recordingsDirectory = recordingsDirectory else { return }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: recordingsDirectory,
                                                          includingPropertiesForKeys: [.creationDateKey],
                                                          options: [])
            let sortedFiles = try files.sorted { file1, file2 in
                let date1 = try file1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                let date2 = try file2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                return date1 > date2
            }
            
            // Keep the most recent file
            if sortedFiles.count > 1 {
                for file in sortedFiles.dropFirst() {
                    try? fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("Error cleaning up recordings: \(error)")
        }
    }
    
    deinit {
        cleanupOldRecordings()
    }
}

