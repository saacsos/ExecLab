#!/bin/bash

FILE="$2"
LANGUAGE="$1"
INPUT_FILE="$3"

if [ ! -f "$FILE" ]; then
    echo "Error: File $FILE not found!"
    exit 1
fi

META_FILE=$(mktemp)
BOX_ID=0
isolate --init --box-id="$BOX_ID" > /dev/null
BOX_PATH="/var/local/lib/isolate/$BOX_ID/box"

BASE_DIRS="--dir=/usr/bin=/usr/bin:rw \
           --dir=/usr/lib=/usr/lib:rw \
           --dir=/lib=/lib:rw"

EXTRA_DIRS=""

case "$LANGUAGE" in
    c)
        cp "$FILE" "$BOX_PATH/source.c"
        isolate --run --box-id="$BOX_ID" \
                $BASE_DIRS \
                --processes=8 \
                --env=PATH=/usr/bin:/bin \
                -- /usr/bin/gcc -O2 source.c -o output

        if [ $? -ne 0 ]; then
            echo "Compilation failed!"
            isolate --cleanup --box-id="$BOX_ID"
            rm -f "$META_FILE"
            exit 1
        fi
        EXECUTE_CMD="./output"
        EXTRA_DIRS=""
        MEM_LIMIT=256000
        PROCESS_LIMIT=1
        ;;
    cpp)
        cp "$FILE" "$BOX_PATH/source.cpp"
        isolate --run --box-id="$BOX_ID" \
                $BASE_DIRS \
                --processes=8 \
                --env=PATH=/usr/bin:/bin \
                -- /usr/bin/g++ -O2 source.cpp -o output

        if [ $? -ne 0 ]; then
            echo "Compilation failed!"
            isolate --cleanup --box-id="$BOX_ID"
            rm -f "$META_FILE"
            exit 1
        fi
        EXECUTE_CMD="./output"
        EXTRA_DIRS=""
        MEM_LIMIT=256000
        PROCESS_LIMIT=1
        ;;
    python)
        cp "$FILE" "$BOX_PATH/main.py"
        EXECUTE_CMD="/usr/bin/python3 main.py"
        EXTRA_DIRS=""
        MEM_LIMIT=256000
        PROCESS_LIMIT=1
        ;;
    javascript|js)
        cp "$FILE" "$BOX_PATH/main.js"
        mkdir -p "$BOX_PATH/usr/local/bun"
        cp -r /usr/local/bun/* "$BOX_PATH/usr/local/bun/"
        EXECUTE_CMD="/usr/local/bun/bin/bun run main.js"
        MEM_LIMIT=512000
        PROCESS_LIMIT=50
        TIME_LIMIT=5.0
        WALL_TIME=10.0
        EXTRA_DIRS="--dir=/usr/local/bun=/usr/local/bun:rw \
            --dir=/lib/aarch64-linux-gnu=/lib/aarch64-linux-gnu:rw \
            --dir=/proc=/proc:rw \
            --dir=/dev=/dev:rw \
            --dir=/lib/ld-linux-aarch64.so.1=/lib/ld-linux-aarch64.so.1:rw"
        ;;
    typescript|ts)
        cp "$FILE" "$BOX_PATH/main.ts"
        mkdir -p "$BOX_PATH/usr/local/bun"
        cp -r /usr/local/bun/* "$BOX_PATH/usr/local/bun/"
        EXECUTE_CMD="/usr/local/bun/bin/bun run main.ts"
        MEM_LIMIT=512000
        PROCESS_LIMIT=50
        TIME_LIMIT=5.0
        WALL_TIME=10.0
        EXTRA_DIRS="--dir=/usr/local/bun=/usr/local/bun:rw \
            --dir=/lib/aarch64-linux-gnu=/lib/aarch64-linux-gnu:rw \
            --dir=/proc=/proc:rw \
            --dir=/dev=/dev:rw \
            --dir=/lib/ld-linux-aarch64.so.1=/lib/ld-linux-aarch64.so.1:rw"
        ;;
    *)
        echo "Unsupported language!"
        echo "Supported languages: c, cpp, python, javascript/js, typescript/ts"
        isolate --cleanup --box-id="$BOX_ID"
        rm -f "$META_FILE"
        exit 1
        ;;
esac

DIRS="$BASE_DIRS $EXTRA_DIRS"

if [ -n "$INPUT_FILE" ]; then
    cp "$INPUT_FILE" "$BOX_PATH/input.txt"
    
    isolate --run --box-id="$BOX_ID" \
            $DIRS \
            --meta="$META_FILE" \
            --time=${TIME_LIMIT:-1.0} \
            --wall-time=${WALL_TIME:-2.0} \
            --mem=$MEM_LIMIT \
            --fsize=32768 \
            --stack=262144 \
            --processes=$PROCESS_LIMIT \
            --share-net \
            --stderr-to-stdout \
            --env=PATH=/usr/bin:/bin:/usr/local/bun/bin \
            --env=BUN_INSTALL=/usr/local/bun \
            --stdin=input.txt \
            --tty \
            -- $EXECUTE_CMD 2>&1
    
    EXIT_CODE=$?
else
    isolate --run --box-id="$BOX_ID" \
            $DIRS \
            --meta="$META_FILE" \
            --time=${TIME_LIMIT:-1.0} \
            --wall-time=${WALL_TIME:-2.0} \
            --mem=$MEM_LIMIT \
            --fsize=32768 \
            --stack=262144 \
            --processes=$PROCESS_LIMIT \
            --share-net \
            --stderr-to-stdout \
            --env=PATH=/usr/bin:/bin:/usr/local/bun/bin \
            --env=BUN_INSTALL=/usr/local/bun \
            --tty \
            -- $EXECUTE_CMD 2>&1
    
    EXIT_CODE=$?
fi

echo -e "\n📊 Status:"
case $EXIT_CODE in
    0)  echo "Program finished successfully" ;;
    1)  echo "Program failed" ;;
    2)  echo "Time limit exceeded" ;;
    3)  echo "Memory limit exceeded" ;;
    *)  echo "Program failed with exit code $EXIT_CODE" ;;
esac

TIME_SECONDS=$(grep "time:" "$META_FILE" | cut -d':' -f2)
MEMORY_BYTES=$(grep "max-rss:" "$META_FILE" | cut -d':' -f2)
TIME_MS=$(awk -v time="$TIME_SECONDS" 'BEGIN {printf "%.3f", time * 1000}')
MEMORY_KB=$((MEMORY_BYTES / 1024))

echo -e "\n⏳ Execution Metrics:"
echo "Time: $TIME_MS ms"
echo "Memory: $MEMORY_KB KB"

isolate --cleanup --box-id="$BOX_ID"
rm -f "$META_FILE"