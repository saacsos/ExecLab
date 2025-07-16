#!/bin/bash

FILE="$2"
LANGUAGE="$1"
INPUT_FILE="$3"

if [ ! -f "$FILE" ]; then
    echo "Error: File $FILE not found!"
    exit 1
fi

export CCACHE_DISABLE=1
export CCACHE_NOHASH=1

TIMESTAMP=$(date +%s%N)
UNIQUE_ID="${USER}_${TIMESTAMP}_$$"

sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

META_FILE=$(mktemp)
BOX_ID=$(shuf -i 1-999 -n 1)

isolate --cleanup --box-id="$BOX_ID" 2>/dev/null || true
isolate --init --box-id="$BOX_ID" > /dev/null
BOX_PATH="/var/local/lib/isolate/$BOX_ID/box"

BASE_DIRS="--dir=/usr/bin=/usr/bin:rw \
           --dir=/usr/lib=/usr/lib:rw \
           --dir=/lib=/lib:rw \
           --dir=/usr/include=/usr/include:rw"

EXTRA_DIRS=""

case "$LANGUAGE" in
    c)
        UNIQUE_SOURCE="source_${UNIQUE_ID}.c"
        cp "$FILE" "$BOX_PATH/$UNIQUE_SOURCE"

        isolate --run --box-id="$BOX_ID" \
                $BASE_DIRS \
                --processes=8 \
                --env=PATH=/usr/bin:/bin \
                --env=CCACHE_DISABLE=1 \
                --env=TMPDIR=/tmp \
                -- /usr/bin/gcc -O2 "$UNIQUE_SOURCE" -o "output_${UNIQUE_ID}"

        if [ $? -ne 0 ]; then
            echo "Compilation failed!"
            isolate --cleanup --box-id="$BOX_ID"
            rm -f "$META_FILE"
            exit 1
        fi
        EXECUTE_CMD="./output_${UNIQUE_ID}"
        MEM_LIMIT=256000
        PROCESS_LIMIT=1
        TIME_LIMIT=5.0
        WALL_TIME=10.0
        ;;
    cpp)
        UNIQUE_SOURCE="source_${UNIQUE_ID}.cpp"
        cp "$FILE" "$BOX_PATH/$UNIQUE_SOURCE"

        isolate --run --box-id="$BOX_ID" \
                $BASE_DIRS \
                --processes=8 \
                --env=PATH=/usr/bin:/bin \
                --env=CCACHE_DISABLE=1 \
                --env=TMPDIR=/tmp \
                -- /usr/bin/g++ -O2 "$UNIQUE_SOURCE" -o "output_${UNIQUE_ID}"

        if [ $? -ne 0 ]; then
            echo "Compilation failed!"
            isolate --cleanup --box-id="$BOX_ID"
            rm -f "$META_FILE"
            exit 1
        fi
        EXECUTE_CMD="./output_${UNIQUE_ID}"
        MEM_LIMIT=256000
        PROCESS_LIMIT=1
        TIME_LIMIT=5.0
        WALL_TIME=10.0
        ;;
    python)
        UNIQUE_SOURCE="main_${UNIQUE_ID}.py"
        cp "$FILE" "$BOX_PATH/$UNIQUE_SOURCE"
        EXECUTE_CMD="/usr/bin/python3 -B $UNIQUE_SOURCE"  # -B disables .pyc files
        MEM_LIMIT=256000
        PROCESS_LIMIT=1
        TIME_LIMIT=5.0
        WALL_TIME=10.0
        ;;
    javascript|js)
        UNIQUE_SOURCE="main_${UNIQUE_ID}.js"
        cp "$FILE" "$BOX_PATH/$UNIQUE_SOURCE"
        
        UNIQUE_BUN_DIR="/tmp/bun_${UNIQUE_ID}"
        mkdir -p "$BOX_PATH$UNIQUE_BUN_DIR"
        cp -r /usr/local/bun/* "$BOX_PATH$UNIQUE_BUN_DIR/"

        EXECUTE_CMD="$UNIQUE_BUN_DIR/bin/bun run $UNIQUE_SOURCE"
        MEM_LIMIT=512000
        PROCESS_LIMIT=50
        TIME_LIMIT=5.0
        WALL_TIME=10.0
        EXTRA_DIRS="--dir=$UNIQUE_BUN_DIR=$UNIQUE_BUN_DIR:rw \
            --dir=/lib/aarch64-linux-gnu=/lib/aarch64-linux-gnu:rw \
            --dir=/proc=/proc:rw \
            --dir=/dev=/dev:rw \
            --dir=/lib/ld-linux-aarch64.so.1=/lib/ld-linux-aarch64.so.1:rw"
        ;;
    typescript|ts)
        UNIQUE_SOURCE="main_${UNIQUE_ID}.ts"
        cp "$FILE" "$BOX_PATH/$UNIQUE_SOURCE"
        
        UNIQUE_BUN_DIR="/tmp/bun_${UNIQUE_ID}"
        mkdir -p "$BOX_PATH$UNIQUE_BUN_DIR"
        cp -r /usr/local/bun/* "$BOX_PATH$UNIQUE_BUN_DIR/"

        EXECUTE_CMD="$UNIQUE_BUN_DIR/bin/bun run $UNIQUE_SOURCE"
        MEM_LIMIT=512000
        PROCESS_LIMIT=50
        TIME_LIMIT=5.0
        WALL_TIME=10.0
        EXTRA_DIRS="--dir=$UNIQUE_BUN_DIR=$UNIQUE_BUN_DIR:rw \
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

sync
echo 1 > /proc/sys/vm/drop_caches 2>/dev/null || true

if [ -n "$INPUT_FILE" ]; then
    UNIQUE_INPUT="input_${UNIQUE_ID}.txt"
    cp "$INPUT_FILE" "$BOX_PATH/$UNIQUE_INPUT"
    
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
            --env=CCACHE_DISABLE=1 \
            --env=PYTHONDONTWRITEBYTECODE=1 \
            --env=TMPDIR=/tmp \
            --stdin="$UNIQUE_INPUT" \
            --tty \
            -- $EXECUTE_CMD 2>&1
    
    EXIT_CODE=$?
else
    isolate --run --box-id="$BOX_ID" \
            $DIRS \
            --meta="$META_FILE" \
            --time=$TIME_LIMIT \
            --wall-time=$WALL_TIME \
            --mem=$MEM_LIMIT \
            --fsize=32768 \
            --stack=262144 \
            --processes=$PROCESS_LIMIT \
            --share-net \
            --stderr-to-stdout \
            --env=PATH=/usr/bin:/bin:/usr/local/bun/bin \
            --env=BUN_INSTALL=/usr/local/bun \
            --env=CCACHE_DISABLE=1 \
            --env=PYTHONDONTWRITEBYTECODE=1 \
            --env=TMPDIR=/tmp \
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

sync
echo 1 > /proc/sys/vm/drop_caches 2>/dev/null || true

exit $EXIT_CODE