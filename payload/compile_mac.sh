#!/bin/sh

# Halt on errors.
set -e

# The path to the `Chromium Embedded Framework` binary file.
# This is usually something along the lines of
# /Applications/League of Legends.app/Contents/LoL/RADS/projects/league_client/releases/HIGHEST_NUMBER/deploy/LeagueClientUx.app/Contents/MacOS/Chromium Embedded Framework
CEF_PATH=''

# If there is no path set, exit.
if [ -z "$CEF_PATH" ]; then
    echo "No path to the 'Chromium Embedded Framework' binary file set.";
    echo "Edit compile_osx.sh in 'payload/', then build or run this again.";
    exit 1;
fi

# Determine which compiler to use.
if [ -x "$(command -v g++)" ]; then
    CC=g++;
elif [ -x "$(command -v clang++)" ]; then
    CC=clang++;
else
    echo "No C++ compiler installed. Aborting.";
    exit 1;
fi

# Check if lipo is installed.
if ! [ -x "$(command -v lipo)" ]; then
    echo "lipo is not installed. Install the Xcode command line tools and try again.";
    exit 1;
fi

FILES='payload.cc'
CFLAGS='-dynamiclib -I.'
OUTPUT=payload.dylib

# Compile 64 bit version.
$CC $CFLAGS $FILES -weak_library "$CEF_PATH" -o tmp64.dylib

# Compile 32 bit version. Note that we do not link with CEF,
# since that is a 64-bit file.
$CC $CFLAGS -m32 $FILES -o tmp32.dylib

# Combine files.
lipo -create -arch i386 tmp32.dylib -arch x86_64 tmp64.dylib -output $OUTPUT

# Remove thrash.
rm tmp64.dylib
rm tmp32.dylib

echo "Compiled to $OUTPUT."