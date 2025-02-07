FROM python:3.9-slim

WORKDIR /app

# Install system dependencies including python3-distutils
RUN apt-get update && apt-get install -y \
    ffmpeg \
    python3-distutils \
    python3-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

# Expose the port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
