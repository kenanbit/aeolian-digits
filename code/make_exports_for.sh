#!/bin/bash

# Usage: ./make_exports_for.sh foo.mscx

if [ -z "$1" ]; then
    echo "No .mscx/.mscz file provided"
    echo "Usage: ./make_exports_for.sh foo.mscx"
    exit 2
fi

if [ ! -f "$1" ]; then
    echo "The file '$1' does not exist"
    echo "Usage: ./make_exports_for.sh foo.mscx"
    exit 2
fi

if [ -z "$DISPLAY" ]; then
    echo "Starting Xvfb virtual display because no DISPLAY is being used...";
    killall Xvfb
    Xvfb :0 -screen 0 800x600x24&
    sleep 1
    export DISPLAY=:0
fi

DIR="`dirname $BASH_SOURCE`"

INPUT=$1
BASE=`basename "$INPUT"`
BASE="${BASE%%.*}"
DIR=`dirname "$INPUT"`"/"

MUSESCORE="/Applications/MuseScore 3.app/Contents/MacOS/mscore"
if [ ! -f "$MUSESCORE" ]; then
    MUSESCORE="musescore"
fi

# Check prerequisites
command -v "$MUSESCORE" >/dev/null 2>&1 || { echo >&2 "Require 'musescore' but can't find it or it's not installed.  Aborting."; exit 1; }
command -v convert >/dev/null 2>&1 || { echo >&2 "Require 'convert' (from ImageMagick) but can't find it or it's not installed.  Aborting."; exit 1; }
command -v identify >/dev/null 2>&1 || { echo >&2 "Require 'identify' (from ImageMagick) but can't find it or it's not installed.  Aborting."; exit 1; }
command -v sox >/dev/null 2>&1 || { echo >&2 "Require 'sox' but can't find it or it's not installed.  Aborting."; exit 1; }


echo_and_run() { echo -e "\e[1m\$ $*\e[0m" ; "$@" || echo "Command failed. Exiting..." || exit 3; }

# Generate PNG of score
TRIM=10
OUTPUT_SCORE_PNG="$DIR$BASE.score.png"
echo_and_run "$MUSESCORE" "$INPUT" -T$TRIM -o "$OUTPUT_SCORE_PNG"
# Correct mscore bad naming https://musescore.org/en/node/285127
MSCORE_OUTPUT="$DIR$BASE.score-1.png"
echo_and_run mv "$MSCORE_OUTPUT" "$OUTPUT_SCORE_PNG"

# Modify mscore's outputted png
echo_and_run convert "$OUTPUT_SCORE_PNG" -background '#DDDDDD' -alpha remove "$OUTPUT_SCORE_PNG"

SCORE_IMAGE_WIDTH=`identify -format "%w" "$OUTPUT_SCORE_PNG"`

# Generate WAV of score
OUTPUT_WAV="$DIR$BASE.wav"
echo_and_run "$MUSESCORE" "$INPUT" -o "$OUTPUT_WAV"

# Trim silence from the end by reversing, trimming from beginning, and reversing
#sox "$OUTPUT_WAV" temp-1.wav reverse
#sox temp-1.wav temp-2.wav silence 1 0.1 1%
#sox temp-2.wav "$OUTPUT_WAV" reverse
#rm temp-1.wav temp-2.wav

# Generate PNG of spectrogram
INPUT="$OUTPUT_WAV"
OUTPUT_SPECTROGRAM_PNG="$DIR$BASE.spectrogram.png"
ARGUMENTS="-n remix 1,2 rate 12k trim 0 -.6 spectrogram -x $((SCORE_IMAGE_WIDTH-50)) -z 80 -q 6 -l"
echo_and_run sox "$INPUT" $ARGUMENTS -o "$OUTPUT_SPECTROGRAM_PNG"

# Modify sox's outputted png
echo_and_run convert "$OUTPUT_SPECTROGRAM_PNG" -alpha set  -channel RGBA -fuzz 01% -fill '#DDDDDD' -opaque '#DED9D1' "$OUTPUT_SPECTROGRAM_PNG"

# Generate a joined file
OUTPUT_JOINED_PNG="$DIR$BASE.png"
echo_and_run convert "$OUTPUT_SCORE_PNG" "$OUTPUT_SPECTROGRAM_PNG" -gravity center -append "$OUTPUT_JOINED_PNG"

# Generate an MP3 file
OUTPUT_MP3="$DIR$BASE.mp3"
echo_and_run lame --resample 32 -a "$OUTPUT_WAV" "$OUTPUT_MP3" 2> /dev/null

# Remove intermediate files
echo_and_run rm "$OUTPUT_SCORE_PNG" "$OUTPUT_SPECTROGRAM_PNG" "$OUTPUT_WAV"
