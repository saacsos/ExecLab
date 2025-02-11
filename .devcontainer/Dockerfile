FROM ubuntu:latest

# Install necessary packages
RUN apt update && apt install -y \
    g++ \
    python3 \
    python3-pip \
    nodejs \
    npm \
    && apt clean

# Set up a working directory
WORKDIR /workspace
