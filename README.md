# MicAudioRecorder

A macOS app that records audio and provides real-time transcription.

## Requirements

- macOS 11.0 or later
- Python 3.9 or later
- Microphone access
- Xcode Command Line Tools (for building the app)

## Installation

1. Download the complete project:
   - Use `git clone https://github.com/nlemoff/audio-transcriber.git`
   - OR download the ZIP file using GitHub's "Code → Download ZIP" button
   - Important: Make sure you have the entire project, including `MicAudioRecorder.xcodeproj`
2. Right-click on `run_app.command` and select "Open"
   - If you get a security warning, go to System Settings -> Privacy & Security and allow the script to run
3. The script will:
   - Build the app using Xcode tools
   - Check for Python and pip
   - Set up a virtual environment
   - Install required Python packages
   - Start the backend server
   - Launch the app

## Usage

1. Click "Record" to start recording audio
2. Click "Stop Recording" when finished
3. Click "Transcribe" to transcribe the recording
4. The transcription will appear in the scrollable area
5. You can record and transcribe multiple messages
6. To quit, press Ctrl+C in the terminal window running the script

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
