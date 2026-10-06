#!/bin/bash

# Check if input file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <input_image> [1080p|4k]"
    exit 1
fi

INPUT="$1"
RESOLUTION="${2:-1080p}" # Default to 1080p if not specified

if command -v magick &> /dev/null; then
    if ! SOURCE_DIMENSIONS=$(magick identify -format '%w %h' "$INPUT"); then
        echo "Error: Could not read input image dimensions: '$INPUT'."
        exit 1
    fi
elif command -v identify &> /dev/null; then
    if ! SOURCE_DIMENSIONS=$(identify -format '%w %h' "$INPUT"); then
        echo "Error: Could not read input image dimensions: '$INPUT'."
        exit 1
    fi
else
    echo "Error: ImageMagick is required to inspect the input image."
    exit 1
fi

read -r SOURCE_WIDTH SOURCE_HEIGHT <<< "$SOURCE_DIMENSIONS"
if ! [[ "$SOURCE_WIDTH" =~ ^[0-9]+$ && "$SOURCE_HEIGHT" =~ ^[0-9]+$ ]]; then
    echo "Error: Could not parse input image dimensions."
    exit 1
fi

if [ "$SOURCE_WIDTH" -ne "$((SOURCE_HEIGHT * 2))" ]; then
    echo "Error: Input image must have a 2:1 equirectangular aspect ratio."
    exit 1
fi

# Determine target dimensions based on selection
if [ "$RESOLUTION" = "4k" ]; then
    WIDTH=3840
    HEIGHT=1920
elif [ "$RESOLUTION" = "1080p" ]; then
    WIDTH=2160
    HEIGHT=1080
else
    echo "Error: Resolution must be either '1080p' or '4k'."
    exit 1
fi

# Get output filename by changing extension to .png
OUTPUT="${INPUT%.*_${RESOLUTION}px.png}"
OUTPUT="${OUTPUT%.*}.png"
OUTPUT="${OUTPUT%.*}-${RESOLUTION}.png"

# Resize within the target bounds without cropping the equirectangular map.
if command -v magick &> /dev/null; then
    magick "$INPUT" -resize "${WIDTH}x${HEIGHT}" "$OUTPUT"
elif command -v convert &> /dev/null; then
    convert "$INPUT" -resize "${WIDTH}x${HEIGHT}" "$OUTPUT"
else
    echo "Error: ImageMagick is not installed. Please install it (e.g., sudo apt install imagemagick)."
    exit 1
fi

echo "Successfully converted '$INPUT' to $RESOLUTION PNG: '$OUTPUT'"