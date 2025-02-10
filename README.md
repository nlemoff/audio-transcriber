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
- Docker Desktop for Mac (for running the transcription backend)

## Installation

### 1. Backend Setup (Required)

First, set up the transcription backend:

```bash
# Install Docker Desktop for Mac if you haven't already
# Download from https://www.docker.com/products/docker-desktop/

# Pull the transcription backend image
docker pull nlemoff/audio-transcription:latest

# Run the backend container
docker run -d -p 8000:8000 nlemoff/audio-transcription:latest
```

### 2. App Setup

1. Clone this repository:
```bash
git clone https://github.com/nlemoff/audio-transcriber.git
cd audio-transcriber
```

2. Open `MicAudioRecorder.xcodeproj` in Xcode
3. Build and run the project

### 3. System Audio Recording Setup (Optional)

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

1. Make sure the Docker container is running:
```bash
# Check if container is running
docker ps | grep audio-transcription

# If not running, start it
docker run -d -p 8000:8000 nlemoff/audio-transcription:latest
```

2. Launch the application
3. Grant microphone permissions when prompted
4. Click "Record" to start recording
5. Click "Stop Recording" to stop
6. Click "Transcribe" to generate transcription

## Development

The project uses:
- SwiftUI for the user interface
- AVFoundation for audio recording
- Core Audio for device management
- Docker container for transcription backend

## License

MIT License

## Troubleshooting

### Backend Issues

1. Check if the backend is running:
```bash
docker ps | grep audio-transcription
```

2. Check backend logs:
```bash
docker logs $(docker ps | grep audio-transcription | awk '{print $1}')
```

3. If the backend isn't responding:
```bash
# Stop existing container
docker stop $(docker ps | grep audio-transcription | awk '{print $1}')

# Remove container
docker rm $(docker ps -a | grep audio-transcription | awk '{print $1}')

# Pull latest image
docker pull nlemoff/audio-transcription:latest

# Start fresh container
docker run -d -p 8000:8000 nlemoff/audio-transcription:latest
```

### App Issues

1. If you get a "Microphone access required" message:
   - Click "Open System Settings"
   - Go to Privacy & Security -> Microphone
   - Enable access for MicAudioRecorder

2. If the app won't open:
   - Right-click the app and select "Open"
   - In System Settings -> Privacy & Security, allow the app to run

3. If system audio recording isn't working:
   - Verify BlackHole is installed and configured
   - Check System Settings > Sound for proper device setup

## Package Contents

- `MicAudioRecorder.app`