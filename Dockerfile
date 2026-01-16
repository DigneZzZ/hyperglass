# =============================================================================
# Multi-location Looking Glass Docker Image
# Based on hyperglass with nginx for speed test files
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Base image with source code
# -----------------------------------------------------------------------------
FROM python:3.12.3-alpine AS base
WORKDIR /opt/hyperglass
ENV HYPERGLASS_APP_PATH=/etc/hyperglass
ENV HYPERGLASS_HOST=0.0.0.0
ENV HYPERGLASS_PORT=8001
ENV HYPERGLASS_DEBUG=false
ENV HYPERGLASS_DEV_MODE=false
ENV HYPERGLASS_REDIS_HOST=redis
ENV HYPEGLASS_DISABLE_UI=true
ENV HYPERGLASS_CONTAINER=true
COPY . .

# -----------------------------------------------------------------------------
# Stage 2: Build UI dependencies
# -----------------------------------------------------------------------------
FROM base AS ui
WORKDIR /opt/hyperglass/hyperglass/ui
RUN apk add build-base pkgconfig cairo-dev nodejs npm
RUN npm install -g pnpm
RUN pnpm install -P

# -----------------------------------------------------------------------------
# Stage 3: Install hyperglass Python package
# -----------------------------------------------------------------------------
FROM ui AS hyperglass-build
WORKDIR /opt/hyperglass
RUN pip3 install -e .

# -----------------------------------------------------------------------------
# Stage 4: Final production image with nginx and speed test files
# -----------------------------------------------------------------------------
FROM hyperglass-build AS production

# Install nginx and required tools
RUN apk add --no-cache nginx bash curl

# Create directories for nginx and speed test files
RUN mkdir -p /var/www/speedtest \
    && mkdir -p /var/log/nginx \
    && mkdir -p /run/nginx \
    && mkdir -p /etc/hyperglass/custom

# Generate speed test files (dummy files for download testing)
# Using /dev/urandom for realistic network testing
RUN dd if=/dev/urandom of=/var/www/speedtest/10MB.bin bs=1M count=10 2>/dev/null \
    && dd if=/dev/urandom of=/var/www/speedtest/100MB.bin bs=1M count=100 2>/dev/null \
    && dd if=/dev/urandom of=/var/www/speedtest/1GB.bin bs=1M count=1024 2>/dev/null \
    && chmod 644 /var/www/speedtest/*.bin

# Copy nginx configuration
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Copy custom UI script
COPY docker/custom_ui.js /etc/hyperglass/custom/custom_ui.js

# Copy entrypoint script
COPY docker/start.sh /start.sh
RUN chmod +x /start.sh

# Expose ports: 8001 for hyperglass, 8080 for nginx speed test server
EXPOSE 8001 8080

# Use custom entrypoint that starts both services
ENTRYPOINT ["/start.sh"]
