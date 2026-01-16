#!/bin/bash
# =============================================================================
# Multi-location Looking Glass Entrypoint Script
# Starts both nginx (speed test server) and hyperglass application
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Configuration
# =============================================================================

HYPERGLASS_APP_PATH="${HYPERGLASS_APP_PATH:-/etc/hyperglass}"
HYPERGLASS_HOST="${HYPERGLASS_HOST:-0.0.0.0}"
HYPERGLASS_PORT="${HYPERGLASS_PORT:-8001}"
NGINX_PORT="${NGINX_PORT:-8080}"

# =============================================================================
# Initialization
# =============================================================================

log_info "Starting Multi-location Looking Glass..."
log_info "Hyperglass port: ${HYPERGLASS_PORT}"
log_info "Nginx speed test port: ${NGINX_PORT}"

# Ensure required directories exist
mkdir -p /var/log/nginx
mkdir -p /run/nginx
mkdir -p "${HYPERGLASS_APP_PATH}"

# =============================================================================
# Copy custom UI script if configured
# =============================================================================

if [ -f "/etc/hyperglass/custom/custom_ui.js" ]; then
    log_info "Custom UI script found"
else
    # Copy default custom UI script if not exists
    if [ -f "/etc/hyperglass/custom_ui.js" ]; then
        mkdir -p "${HYPERGLASS_APP_PATH}/custom"
        cp /etc/hyperglass/custom_ui.js "${HYPERGLASS_APP_PATH}/custom/"
        log_success "Copied custom UI script to app path"
    fi
fi

# =============================================================================
# Verify speed test files
# =============================================================================

if [ -d "/var/www/speedtest" ]; then
    log_info "Speed test files:"
    ls -lh /var/www/speedtest/*.bin 2>/dev/null || log_warn "No speed test files found"
else
    log_warn "Speed test directory not found at /var/www/speedtest"
fi

# =============================================================================
# Test nginx configuration
# =============================================================================

log_info "Testing nginx configuration..."
if nginx -t 2>/dev/null; then
    log_success "Nginx configuration is valid"
else
    log_error "Nginx configuration test failed"
    nginx -t
    exit 1
fi

# =============================================================================
# Start nginx in background
# =============================================================================

log_info "Starting nginx..."
nginx -g 'daemon off;' &
NGINX_PID=$!

# Wait a moment for nginx to start
sleep 1

if kill -0 $NGINX_PID 2>/dev/null; then
    log_success "Nginx started (PID: $NGINX_PID)"
else
    log_error "Failed to start nginx"
    exit 1
fi

# =============================================================================
# Graceful shutdown handler
# =============================================================================

cleanup() {
    log_info "Shutting down..."
    
    # Stop nginx
    if [ -n "$NGINX_PID" ] && kill -0 $NGINX_PID 2>/dev/null; then
        log_info "Stopping nginx..."
        kill -SIGTERM $NGINX_PID 2>/dev/null || true
        wait $NGINX_PID 2>/dev/null || true
    fi
    
    # Stop hyperglass
    if [ -n "$HYPERGLASS_PID" ] && kill -0 $HYPERGLASS_PID 2>/dev/null; then
        log_info "Stopping hyperglass..."
        kill -SIGTERM $HYPERGLASS_PID 2>/dev/null || true
        wait $HYPERGLASS_PID 2>/dev/null || true
    fi
    
    log_success "Shutdown complete"
    exit 0
}

trap cleanup SIGTERM SIGINT SIGQUIT

# =============================================================================
# Start hyperglass
# =============================================================================

log_info "Starting hyperglass..."
cd /opt/hyperglass

# Start hyperglass in foreground (main process)
python3 -m hyperglass.console start &
HYPERGLASS_PID=$!

log_success "Hyperglass started (PID: $HYPERGLASS_PID)"

# =============================================================================
# Health check loop
# =============================================================================

log_info "Services running. Monitoring health..."

while true; do
    # Check nginx
    if ! kill -0 $NGINX_PID 2>/dev/null; then
        log_error "Nginx process died unexpectedly"
        cleanup
    fi
    
    # Check hyperglass
    if ! kill -0 $HYPERGLASS_PID 2>/dev/null; then
        log_error "Hyperglass process died unexpectedly"
        cleanup
    fi
    
    sleep 5
done
