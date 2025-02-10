//
//  MicAudioRecorderApp.swift
//  MicAudioRecorder
//
//  Created by Nicholas Lemoff on 2/6/25.
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.nicholaslemoff.MicAudioRecorder", category: "App")

@main
struct MicAudioRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        logger.info("MicAudioRecorderApp initializing")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    logger.info("ContentView appeared")
                }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Application did finish launching")
        
        // Ensure we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.activateApp()
            }
        } else {
            activateApp()
        }
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        logger.info("Application will finish launching")
    }
    
    private func activateApp() {
        // Set activation policy
        NSApp.setActivationPolicy(.regular)
        
        // Activate the app
        NSApp.activate(ignoringOtherApps: true)
        
        // Make sure we have a key window
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
        
        logger.info("App activation completed")
    }
}
