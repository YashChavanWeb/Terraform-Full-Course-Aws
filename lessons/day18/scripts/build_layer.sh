#!/bin/bash
set -e

echo "🚀 Building Lambda Layer with Pillow using Docker..."

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
TERRAFORM_DIR="$PROJECT_DIR/terraform"

# Create terraform directory if it doesn't exist
mkdir -p "$TERRAFORM_DIR"

# Build using Docker for consistent environment
docker run --rm \
  --platform linux/amd64 \
  -v "$TERRAFORM_DIR":/output \
  python:3.12-slim \
  bash -c "
    echo 'Installing system dependencies...' && \
    apt-get update -qq && apt-get install -y -qq zip > /dev/null 2>&1 && \
    echo 'Installing Pillow for Linux AMD64...' && \
    mkdir -p /tmp/python/lib/python3.12/site-packages && \
    pip install --quiet --no-cache-dir Pillow==10.4.0 -t /tmp/python/lib/python3.12/site-packages && \
    cd /tmp && \
    echo 'Creating layer zip file...' && \
    zip -q -r pillow_layer.zip python/ && \
    cp pillow_layer.zip /output/ && \
    echo 'Layer built successfully for Linux AMD64 (Lambda-compatible)'
  "

echo "✅ Layer built successfully using Docker!"
echo "📍 Location: $TERRAFORM_DIR/pillow_layer.zip"