//
//  AudioRecorder.swift
//  MicAudioRecorder
//
//  Created by Nicholas Lemoff on 2/6/25.
//

import Foundation
import AVFoundation
import AppKit
import CoreAudio

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var permissionGranted = false
    @Published var audioFileURL: URL?
    @Published var isBlackHoleInstalled = false
    private var recordingCount = 0
    private let fileManager = FileManager.default
    private var recordingsDirectory: URL?
    private let audioEngine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private var audioFile: AVAudioFile?
    
    override init() {
        super.init()
        setupRecordingsDirectory()
        checkBlackHoleInstallation()
        setupAudioEngine()
        checkMicrophoneAuthorization()
    }
    
    private func checkBlackHoleInstallation() {
        // Use Core Audio to check for BlackHole
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var devices: [AudioDeviceID] = []
        var deviceCount: UInt32 = 0
        
        // Get device count
        var result = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &deviceCount
        )
        
        if result == noErr {
            // Get devices
            devices = Array(repeating: AudioDeviceID(), count: Int(deviceCount))
            result = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &deviceCount,
                &devices
            )
            
            if result == noErr {
                // Check each device for BlackHole
                for device in devices {
                    var nameProperty = AudioObjectPropertyAddress(
                        mSelector: kAudioDevicePropertyDeviceNameCFString,
                        mScope: kAudioObjectPropertyScopeGlobal,
                        mElement: kAudioObjectPropertyElementMain
                    )
                    
                    var cfName: CFString? = nil
                    var propSize = UInt32(MemoryLayout<CFString?>.size)
                    result = AudioObjectGetPropertyData(
                        device,
                        &nameProperty,
                        0,
                        nil,
                        &propSize,
                        &cfName
                    )
                    
                    if result == noErr, let deviceName = cfName as String? {
                        if deviceName.lowercased().contains("blackhole") {
                            isBlackHoleInstalled = true
                            break
                        }
                    }
                }
            }
        }
        
        print("BlackHole installation status: \(isBlackHoleInstalled)")
    }
    
    func openBlackHoleInstallPage() {
        if let url = URL(string: "https://github.com/ExistentialAudio/BlackHole") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func setupAudioEngine() {
        do {
            print("Setting up audio engine...")
            if audioEngine.isRunning {
                print("Stopping running audio engine")
                audioEngine.stop()
            }
            
            print("Resetting audio engine")
            audioEngine.reset()
            
            print("Attaching mixer node")
            audioEngine.attach(mixer)
            
            let inputNode = audioEngine.inputNode
            let hardwareFormat = inputNode.outputFormat(forBus: 0)
            print("Input hardware format: \(hardwareFormat)")
            
            // Set the mixer's input and output format to match the hardware
            print("Connecting input to mixer")
            audioEngine.connect(inputNode, to: mixer, format: hardwareFormat)
            
            print("Preparing audio engine")
            audioEngine.prepare()
            
            print("Audio engine setup complete")
            
        } catch {
            print("Error setting up audio engine: \(error)")
        }
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
    
    private func checkMicrophoneAuthorization() {
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
            DispatchQueue.main.async {
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
            }
        case .restricted:
            print("Microphone access restricted")
            self.permissionGranted = false
        @unknown default:
            print("Unknown authorization status")
            self.permissionGranted = false
        }
    }
    
    func startRecording() {
        print("Starting recording...")
        guard permissionGranted else {
            print("Cannot start recording - microphone access not granted")
            checkMicrophoneAuthorization()
            return
        }
        
        guard let recordingsDirectory = recordingsDirectory else {
            print("Recordings directory not set up")
            return
        }
        
        recordingCount += 1
        let fileName = "recording_\(Int(Date().timeIntervalSince1970))_\(recordingCount).wav"
        let url = recordingsDirectory.appendingPathComponent(fileName)
        print("Will save recording to: \(url.path)")
        
        do {
            // Get the hardware format from input node
            let inputNode = audioEngine.inputNode
            let hardwareFormat = inputNode.outputFormat(forBus: 0)
            print("Hardware format for recording: \(hardwareFormat)")
            
            // Create audio file with hardware format
            print("Creating audio file...")
            audioFile = try AVAudioFile(forWriting: url, settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: hardwareFormat.sampleRate,
                AVNumberOfChannelsKey: hardwareFormat.channelCount,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ])
            
            print("Installing tap on mixer...")
            mixer.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { [weak self] buffer, time in
                guard let self = self, let audioFile = self.audioFile else {
                    print("Error: Self or audio file is nil in tap block")
                    return
                }
                do {
                    try audioFile.write(from: buffer)
                } catch {
                    print("Error writing audio buffer: \(error)")
                }
            }
            
            print("Starting audio engine...")
            try audioEngine.start()
            
            isRecording = true
            audioFileURL = url
            print("Recording started successfully at: \(url.path)")
        } catch {
            print("Error setting up recording: \(error.localizedDescription)")
            // Try to recover from the error
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            mixer.removeTap(onBus: 0)
            audioFile = nil
            setupAudioEngine() // Reinitialize the audio engine
        }
    }
    
    func stopRecording() {
        print("Stopping recording...")
        // Remove the tap from the mixer
        mixer.removeTap(onBus: 0)
        
        // Stop the engine
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioFile = nil
        
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
        
        // Reinitialize the audio engine for the next recording
        setupAudioEngine()
    }
    
    deinit {
        cleanupOldRecordings()
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
}

