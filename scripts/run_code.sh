#!/bin/bash

# Usage: run_code.sh <language> <filename> <input_file>
FILE="$2"
LANGUAGE="$1"
INPUT_FILE="$3"  # Optional input redirection

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo "Error: File $FILE not found!"
    exit 1
fi

# Redirect input from file if provided
INPUT_REDIRECT=""
if [ -f "$INPUT_FILE" ]; then
    INPUT_REDIRECT="< $INPUT_FILE"
fi

# Measure execution time and memory usage
/usr/bin/time -f "\nTime: %E\nMemory: %M KB" bash -c "
    case $LANGUAGE in
        cpp)
            g++ $FILE -o output && ./output $INPUT_REDIRECT
            ;;
        python)
            python3 $FILE $INPUT_REDIRECT
            ;;
        java)
            javac $FILE && java ${FILE%.java} $INPUT_REDIRECT
            ;;
        node)
            node $FILE $INPUT_REDIRECT
            ;;
        *)
            echo 'Unsupported language!'
            exit 1
            ;;
    esac
"
