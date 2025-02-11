FROM ubuntu:22.04

# Install required dependencies
RUN apt update && apt install -y \
    g++ \
    python3 \
    nodejs \
    # openjdk-17-jdk \
    time && \
    rm -rf /var/lib/apt/lists/*

# Create workspace
WORKDIR /workspace
COPY scripts/run_code.sh /usr/local/bin/run_code
RUN chmod +x /usr/local/bin/run_code

# Default command (can be overridden dynamically)
# ENTRYPOINT ["run_code"]
