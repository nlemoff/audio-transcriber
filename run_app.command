#!/bin/bash

# Change to the script's directory
cd "$(dirname "$0")"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "Python 3 is required but not installed. Please install Python 3 from python.org"
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "pip3 is required but not installed. Please install pip3"
    exit 1
fi

# Check if virtual environment exists, if not create it
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install requirements
echo "Installing Python dependencies..."
pip3 install -r fastapi-backend/requirements.txt

# Start the FastAPI backend server
echo "Starting backend server..."
cd fastapi-backend
python3 -m uvicorn main:app --host 127.0.0.1 --port 8000 &
BACKEND_PID=$!

# Wait a moment for the server to start
sleep 2

# Open the macOS app
echo "Starting MicAudioRecorder..."
open MicAudioRecorder.app

# Function to handle script termination
cleanup() {
    echo "Shutting down..."
    kill $BACKEND_PID
    deactivate
    exit 0
}

# Set up trap for cleanup
trap cleanup SIGINT SIGTERM

# Keep script running
echo "App is running. Press Ctrl+C to quit."
wait 