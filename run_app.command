#!/bin/bash

# Get the directory containing this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode command line tools are not installed."
    echo "Please install Xcode from the App Store or install the command line tools using:"
    echo "xcode-select --install"
    exit 1
fi

# Build the app
echo "Building MicAudioRecorder..."
xcodebuild -project MicAudioRecorder.xcodeproj -scheme MicAudioRecorder -configuration Debug build

if [ $? -ne 0 ]; then
    echo "Error: Failed to build the application"
    exit 1
fi

# Get the built app path
APP_PATH="$DIR/build/Debug/MicAudioRecorder.app"

# Check if BlackHole is installed
if ! system_profiler SPAudioDataType | grep -q "BlackHole"; then
    echo "Note: BlackHole audio driver is not installed."
    echo "To record system audio, please install BlackHole from:"
    echo "https://github.com/ExistentialAudio/BlackHole"
    echo ""
fi

# Launch the app
echo "Launching MicAudioRecorder..."
open "$APP_PATH"

echo "App launched successfully!" 