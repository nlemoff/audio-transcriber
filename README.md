# MicAudioRecorder

A macOS application that records audio from both microphone and system audio (browser, applications, etc.) and provides real-time transcription.

## Features

- Record from microphone
- Record system audio (requires BlackHole audio driver)
- Real-time audio transcription
- Clean, modern user interface
- Automatic file management

## Requirements

- macOS 11.0 or later
- Xcode 14.0 or later (for development)
- BlackHole 2ch audio driver (for system audio recording)

## Installation

1. Clone this repository
2. Open `MicAudioRecorder.xcodeproj` in Xcode
3. Build and run the project

### System Audio Recording Setup

To record system audio, you'll need to:

1. Install BlackHole audio driver:
   - Visit https://github.com/ExistentialAudio/BlackHole
   - Follow installation instructions
   
2. Configure System Audio:
   - Open System Settings > Sound
   - Create a Multi-Output Device with:
     - Your Speakers
     - BlackHole 2ch
   - Set Multi-Output as default output
   - Set BlackHole 2ch as default input

## Usage

1. Launch the application
2. Grant microphone permissions when prompted
3. Click "Record" to start recording
4. Click "Stop Recording" to stop
5. Click "Transcribe" to generate transcription

## Development

The project uses:
- SwiftUI for the user interface
- AVFoundation for audio recording
- Core Audio for device management

## License

MIT License

## Troubleshooting

1. If you get a "Microphone access required" message:
   - Click "Open System Settings"
   - Go to Privacy & Security -> Microphone
   - Enable access for MicAudioRecorder

2. If the backend server fails to start:
   - Make sure port 8000 is not in use
   - Check that Python and pip are installed correctly
   - Try running `pip3 install -r fastapi-backend/requirements.txt` manually

3. If the app won't open:
   - Right-click the app and select "Open"
   - In System Settings -> Privacy & Security, allow the app to run

## Package Contents

- `MicAudioRecorder.app` - The main application
- `fastapi-backend/` - The Python backend server
- `run_app.command` - Setup and launch script
- `README.md` - This file

## Notes

- The backend server must be running for transcription to work
- Internet connection is required for transcription
- Recordings are stored temporarily and cleaned up when the app closes 
