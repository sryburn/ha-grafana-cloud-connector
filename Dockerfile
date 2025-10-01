ARG BUILD_FROM
FROM $BUILD_FROM

# Install required packages for the Grafana installation script
RUN apk add --no-cache \
    bash \
    curl \
    gettext \
    unzip \
    libc6-compat

# Copy application files
COPY rootfs /
RUN chmod +x /run.sh

# Download and install Grafana Alloy
ARG BUILD_ARCH
RUN ARCH_MAP="amd64=amd64 aarch64=arm64 armv7=armhf"; \
    MAPPED_ARCH=$(echo "$ARCH_MAP" | tr ' ' '\n' | grep "^${BUILD_ARCH}=" | cut -d'=' -f2); \
    if [ -z "$MAPPED_ARCH" ]; then MAPPED_ARCH="$BUILD_ARCH"; fi; \
    curl -fsSL -o /tmp/alloy.zip "https://github.com/grafana/alloy/releases/download/v1.8.3/alloy-linux-${MAPPED_ARCH}.zip" && \
    cd /tmp && \
    unzip alloy.zip && \
    mv alloy-linux-${MAPPED_ARCH} /usr/local/bin/alloy && \
    chmod +x /usr/local/bin/alloy && \
    rm -rf /tmp/alloy*

# Create config directory
RUN mkdir -p /etc/alloy

ENTRYPOINT []
CMD ["/run.sh"]