import asyncio
import json
import tempfile
import os
from typing import AsyncGenerator

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import StreamingResponse
from faster_whisper import WhisperModel
from pydub import AudioSegment

app = FastAPI()

# Initialize the Whisper model with better settings for accuracy
model = WhisperModel(
    "base",  # Using base model for better accuracy
    device="cpu",
    compute_type="int8",
    local_files_only=False,
    download_root=None
)

async def process_audio_file(file: UploadFile) -> str:
    """Save uploaded audio file to a temporary file and convert if needed."""
    print(f"Processing audio file: {file.filename}")
    
    try:
        # Create a temporary file to store the uploaded audio
        with tempfile.NamedTemporaryFile(delete=False, suffix=".m4a") as temp_audio:
            # Write uploaded file to temporary file
            content = await file.read()
            temp_audio.write(content)
            temp_audio.flush()
            print(f"Saved temporary file: {temp_audio.name}")
            
            try:
                # Try to load the audio file directly
                audio = AudioSegment.from_file(temp_audio.name)
            except:
                # If that fails, try explicitly as m4a
                audio = AudioSegment.from_file(temp_audio.name, format="m4a")
            
            # Normalize the audio
            audio = audio.normalize()
            
            # Export as WAV with specific parameters
            wav_path = temp_audio.name + ".wav"
            audio.export(
                wav_path,
                format="wav",
                parameters=[
                    "-ar", "44100",  # Sample rate
                    "-ac", "1",      # Mono
                    "-acodec", "pcm_s16le"  # 16-bit PCM
                ]
            )
            print(f"Converted to WAV: {wav_path}")
            print(f"Audio duration: {len(audio)/1000:.2f} seconds")
            return wav_path
            
    except Exception as e:
        print(f"Error processing audio: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Error processing audio: {str(e)}")

async def transcribe_audio(file_path: str) -> AsyncGenerator[str, None]:
    """
    Transcribe audio file and yield results with speaker diarization.
    """
    try:
        print("Starting transcription...")
        # Transcribe with better parameters
        segments, info = model.transcribe(
            file_path,
            beam_size=5,
            word_timestamps=True,
            vad_filter=True,
            vad_parameters=dict(
                min_speech_duration_ms=100,    # Shorter minimum speech duration
                max_speech_duration_s=float('inf'),
                min_silence_duration_ms=100,   # Shorter silence duration
                speech_pad_ms=100,            # Add padding to speech segments
                window_size_samples=1024
            ),
            temperature=0.0,  # Use greedy decoding
            compression_ratio_threshold=2.4,
            condition_on_previous_text=True,
            initial_prompt="The following is a transcription of clear speech:"
        )
        print(f"Transcription info: {info}")
        
        current_speaker = "Speaker 1"
        last_end_time = 0
        
        for segment in segments:
            # Check for significant pause between segments
            if segment.start - last_end_time > 0.5:
                current_speaker = "Speaker 2" if current_speaker == "Speaker 1" else "Speaker 1"
            
            text = segment.text.strip()
            if text:  # Only yield non-empty segments
                result = {
                    "speaker": current_speaker,
                    "text": text,
                    "start": segment.start,
                    "end": segment.end,
                    "complete": False
                }
                
                print(f"Segment: {result}")
                last_end_time = segment.end
                yield json.dumps(result) + "\n"
                await asyncio.sleep(0.1)  # Small delay to simulate real-time processing
            
        # Send completion message
        yield json.dumps({"complete": True}) + "\n"
        
    except Exception as e:
        print(f"Error in transcription: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Transcription error: {str(e)}")
    finally:
        # Cleanup temporary files
        try:
            os.remove(file_path)
            os.remove(file_path[:-4])  # Remove original m4a file
        except Exception as e:
            print(f"Error cleaning up files: {str(e)}")

@app.post("/transcribe")
async def transcribe(file: UploadFile = File(...)):
    """
    Endpoint to receive an audio file upload and stream back the transcript as
    Server-Sent Events.
    """
    try:
        file_path = await process_audio_file(file)
        
        async def event_generator():
            async for transcript in transcribe_audio(file_path):
                yield f"data: {transcript}\n\n"
        
        return StreamingResponse(
            event_generator(),
            media_type="text/event-stream",
            headers={
                'Cache-Control': 'no-cache',
                'Connection': 'keep-alive',
            }
        )
    except Exception as e:
        print(f"Error in transcribe endpoint: {str(e)}")
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=str(e))
