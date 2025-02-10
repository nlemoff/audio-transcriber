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
    @Published var isInitialized = false
    private var recordingCount = 0
    private let fileManager = FileManager.default
    private var recordingsDirectory: URL?
    private let audioEngine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private var audioFile: AVAudioFile?
    private var captureSession: AVCaptureSession?
    private var audioInput: AVCaptureDeviceInput?
    
    override init() {
        super.init()
        // Defer setup to avoid blocking initialization
        DispatchQueue.main.async { [weak self] in
            self?.setupRecordingsDirectory()
        }
    }
    
    func initialize() {
        // Only initialize once and ensure we're on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Don't initialize twice
            guard !self.isInitialized else {
                print("AudioRecorder already initialized")
                return
            }
            
            print("Starting AudioRecorder initialization")
            
            // Check microphone authorization first
            let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            print("Current audio authorization status: \(authStatus.rawValue)")
            
            switch authStatus {
            case .authorized:
                print("Microphone access already authorized")
                self.permissionGranted = true
                self.initializeAudioComponents()
                
            case .notDetermined:
                print("Requesting microphone access...")
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.permissionGranted = granted
                        print("Microphone access \(granted ? "granted" : "denied")")
                        if granted {
                            self.initializeAudioComponents()
                        } else {
                            self.isInitialized = true
                        }
                    }
                }
                
            case .denied, .restricted:
                print("Microphone access denied or restricted")
                self.permissionGranted = false
                self.isInitialized = true
                
            @unknown default:
                print("Unknown authorization status")
                self.permissionGranted = false
                self.isInitialized = true
            }
        }
    }
    
    private func initializeAudioComponents() {
        // Run audio setup on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Setup components with timeouts
            let setupGroup = DispatchGroup()
            
            // Check BlackHole installation
            setupGroup.enter()
            self.checkBlackHoleInstallation()
            setupGroup.leave()
            
            // Setup audio engine
            setupGroup.enter()
            self.setupAudioEngine()
            setupGroup.leave()
            
            // Setup system audio capture
            setupGroup.enter()
            self.setupSystemAudioCapture()
            setupGroup.leave()
            
            // Wait for all setup to complete with timeout
            let result = setupGroup.wait(timeout: .now() + 5.0)
            
            DispatchQueue.main.async {
                if result == .timedOut {
                    print("Audio setup timed out")
                } else {
                    print("Audio setup completed successfully")
                }
                self.isInitialized = true
            }
        }
    }
    
    func showMicrophonePermissionAlert() {
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
    }
    
    private func checkMicrophoneAuthorization() {
        // This is now handled during initialization
        if !permissionGranted {
            showMicrophonePermissionAlert()
        }
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
    
    private func setupSystemAudioCapture() {
        guard isBlackHoleInstalled else { return }
        
        // Find BlackHole audio device using AVCaptureDevice.DiscoverySession
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )
        
        let blackHoleDevice = discoverySession.devices.first { device in
            device.localizedName.lowercased().contains("blackhole")
        }
        
        if let device = blackHoleDevice {
            do {
                // Create capture session if needed
                if captureSession == nil {
                    captureSession = AVCaptureSession()
                    print("Created new capture session")
                }
                
                // Only reconfigure if not already configured
                if captureSession?.inputs.isEmpty ?? true {
                    captureSession?.beginConfiguration()
                    
                    // Create and add new input
                    audioInput = try AVCaptureDeviceInput(device: device)
                    
                    if let captureSession = captureSession,
                       let audioInput = audioInput,
                       captureSession.canAddInput(audioInput) {
                        captureSession.addInput(audioInput)
                        print("Added BlackHole input to capture session")
                        captureSession.commitConfiguration()
                    } else {
                        captureSession?.commitConfiguration()
                        print("Failed to add BlackHole input to capture session")
                    }
                }
                
                // Start the session if it's not running
                if !(captureSession?.isRunning ?? false) {
                    captureSession?.startRunning()
                    print("Started capture session")
                }
            } catch let error {
                print("Error setting up system audio capture: \(error)")
                captureSession?.commitConfiguration()
            }
        } else {
            print("Could not find BlackHole audio device")
        }
    }
    
    private func setupAudioEngine() {
        print("Setting up audio engine...")
        if audioEngine.isRunning {
            print("Stopping running audio engine")
            audioEngine.stop()
        }
        
        print("Resetting audio engine")
        audioEngine.reset()
        
        print("Attaching mixer node")
        audioEngine.attach(mixer)
        
        // Get the default input (microphone)
        let inputNode = audioEngine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        print("Microphone format: \(hardwareFormat)")
        
        // Create stereo format for all connections
        guard let stereoFormat = AVAudioFormat(
            standardFormatWithSampleRate: 48000,
            channels: 2
        ) else {
            print("Failed to create stereo format")
            return
        }
        
        // Create submixer nodes for each input
        let micMixer = AVAudioMixerNode()
        let blackHoleMixer = AVAudioMixerNode()
        audioEngine.attach(micMixer)
        audioEngine.attach(blackHoleMixer)
        
        // Connect microphone input to its submixer
        audioEngine.connect(inputNode, to: micMixer, format: hardwareFormat)
        audioEngine.connect(micMixer, to: mixer, format: stereoFormat)
        micMixer.pan = -1.0  // Pan microphone to left
        micMixer.volume = 0.8
        
        // Create and connect BlackHole input if available
        if let blackHoleDevice = findBlackHoleDevice() {
            print("Found BlackHole device")
            
            // Create a source node for BlackHole input
            let blackHoleInput = AVAudioSourceNode { [weak self] _, timeStamp, frameCount, audioBufferList -> OSStatus in
                guard let self = self else { return noErr }
                
                let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
                
                // Check if capture session is running and properly configured
                if let session = self.captureSession,
                   session.isRunning,
                   let input = self.audioInput,
                   session.inputs.contains(input) {
                    
                    // Process each buffer in the audio buffer list
                    for buffer in ablPointer {
                        guard let mData = buffer.mData else { continue }
                        
                        // Set a small DC offset to keep the audio chain active
                        let floatData = mData.assumingMemoryBound(to: Float.self)
                        for frame in 0..<Int(frameCount) {
                            // Add a tiny DC offset to maintain the audio chain
                            if floatData[frame] == 0 {
                                floatData[frame] = 0.000001
                            }
                        }
                    }
                    return noErr
                } else {
                    // Fill with silence if capture session is not properly configured
                    for buffer in ablPointer {
                        memset(buffer.mData, 0, Int(buffer.mDataByteSize))
                    }
                    return noErr
                }
            }
            
            audioEngine.attach(blackHoleInput)
            
            // Connect BlackHole input directly to its submixer with stereo format
            audioEngine.connect(blackHoleInput, to: blackHoleMixer, format: stereoFormat)
            audioEngine.connect(blackHoleMixer, to: mixer, format: stereoFormat)
            
            blackHoleMixer.pan = 1.0  // Pan BlackHole to right
            blackHoleMixer.volume = 1.0
            
            print("Connected BlackHole input to mixer")
        }
        
        // Ensure output is muted to prevent feedback
        audioEngine.mainMixerNode.volume = 0
        
        print("Preparing audio engine")
        do {
            try audioEngine.prepare()
            print("Audio engine setup complete")
        } catch {
            print("Error preparing audio engine: \(error)")
        }
    }
    
    private func getBlackHoleFormat(deviceID: AudioDeviceID) throws -> AVAudioFormat {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormat,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: 0
        )
        
        var streamFormat = AudioStreamBasicDescription()
        var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &streamFormat
        )
        
        guard status == noErr else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        
        return AVAudioFormat(
            standardFormatWithSampleRate: 48000,
            channels: 2
        ) ?? AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
    }
    
    private func findBlackHoleDevice() -> AudioDeviceID? {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let result = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize
        )
        
        guard result == noErr else {
            print("Error getting audio devices size: \(result)")
            return nil
        }
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        let getDevicesResult = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &devices
        )
        
        guard getDevicesResult == noErr else {
            print("Error getting audio devices: \(getDevicesResult)")
            return nil
        }
        
        for device in devices {
            var name: CFString?
            var propertySize = UInt32(MemoryLayout<CFString?>.size)
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            let getNameResult = AudioObjectGetPropertyData(
                device,
                &nameAddress,
                0,
                nil,
                &propertySize,
                &name
            )
            
            if getNameResult == noErr,
               let deviceName = name as String?,
               deviceName.lowercased().contains("blackhole") {
                return device
            }
        }
        
        return nil
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
        
        // Ensure capture session is running but don't reinitialize
        if let session = captureSession, !session.isRunning {
            session.startRunning()
            print("Resumed capture session")
        }
        
        recordingCount += 1
        let fileName = "recording_\(Int(Date().timeIntervalSince1970))_\(recordingCount).wav"
        let url = recordingsDirectory.appendingPathComponent(fileName)
        print("Will save recording to: \(url.path)")
        
        do {
            // Create audio file with stereo format
            let recordingFormat = AVAudioFormat(
                standardFormatWithSampleRate: 48000,
                channels: 2
            )!
            
            print("Creating audio file...")
            audioFile = try AVAudioFile(forWriting: url, settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ])
            
            print("Installing tap on mixer...")
            mixer.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, time in
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
            
            // Don't stop the capture session, just reinitialize the audio engine
            setupAudioEngine()
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
        
        // Reinitialize the audio engine but keep the capture session running
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


