FROM ubuntu:22.04 AS isolate

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    git build-essential \
    pkg-config \
    libsystemd-dev libcap-dev

RUN git clone https://github.com/ioi/isolate.git

WORKDIR /isolate

RUN make isolate


FROM ubuntu:22.04 AS runner

# Install required dependencies
RUN apt update && apt install -y \
    g++ \
    python3 \
    nodejs \
    time

RUN apt install -y \
    binutils \
    libstdc++6
RUN apt install -y binutils-aarch64-linux-gnu

RUN apt install -y libcap2-bin
RUN rm -rf /var/lib/apt/lists/*

# Create runner user and group
RUN groupadd -g 60000 runner
RUN useradd -u 60000 -g runner -d /home/runner -m -s /bin/bash runner

RUN mkdir -p /var/local/lib/isolate

COPY --from=isolate /isolate/isolate /usr/local/bin/isolate
COPY .devcontainer/isolate.conf /usr/local/etc/isolate

# Create workspace and isolate directories
WORKDIR /workspace


# Set permissions for isolate to run properly
RUN chmod 755 /usr/local/bin/isolate
RUN chmod -R 777 /var/local/lib/isolate /usr/local/etc/isolate
RUN chmod 644 /usr/local/etc/isolate
RUN chown -R runner:runner /var/local/lib/isolate

COPY scripts/run_code.sh /usr/local/bin/run_code
RUN chmod +x /usr/local/bin/run_code