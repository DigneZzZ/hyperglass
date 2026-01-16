# Multi-location Looking Glass Docker Setup

This directory contains all the necessary files to build and run a multi-location network looking glass based on [hyperglass](https://github.com/thatmattlove/hyperglass) with additional features:

- **Location Navigation Bar** - Switch between different datacenter locations
- **Speed Test Downloads** - Download test files (10MB, 100MB, 1GB) to measure network performance
- **Docker-ready** - Single image with nginx + hyperglass
- **Caddy Reverse Proxy** - Automatic HTTPS with Let's Encrypt

## Directory Structure

```
docker/
├── Caddyfile              # Caddy reverse proxy configuration
├── custom_ui.js           # JavaScript for location nav and speed test UI
├── nginx.conf             # Nginx configuration for speed test server
├── start.sh               # Entrypoint script (starts nginx + hyperglass)
├── docker-compose.yml     # Docker Compose for production
├── .env.example           # Example environment variables
├── hyperglass.yaml.example # Example hyperglass configuration
└── lg-config.js.example   # Example location/speed test configuration
```

## Quick Start

### 1. Clone and Prepare

```bash
# Clone the repository
git clone https://github.com/DigneZzZ/hyperglass.git /opt/hyperglass
cd /opt/hyperglass/docker
```

### 2. Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit with your domain and email
nano .env
```

Set your values:
```env
LG_DOMAIN=lg.example.com
LG_EMAIL=admin@example.com
```

### 3. Create Configuration

```bash
mkdir -p config/custom

# Copy example config
cp hyperglass.yaml.example config/hyperglass.yaml

# Create custom UI config with your locations
cat lg-config.js.example custom_ui.js > config/custom/custom_ui.js

# Edit your locations
nano config/custom/custom_ui.js
```

### 4. Configure Your Locations

Edit `config/custom/custom_ui.js` - update `window.LOOKING_GLASS_CONFIG`:

```javascript
window.LOOKING_GLASS_CONFIG = {
  currentLocation: 'moscow',  // This instance's location ID
  locations: [
    { id: 'moscow', name: 'Moscow, RU', url: 'https://lg-msk.example.com', flag: '🇷🇺' },
    { id: 'amsterdam', name: 'Amsterdam, NL', url: 'https://lg-ams.example.com', flag: '🇳🇱' },
    // Add more locations...
  ],
  speedTest: {
    enabled: true,
    baseUrl: '/speedtest',
    files: [
      { name: '10 MB', file: '10MB.bin', size: '10 MB' },
      { name: '100 MB', file: '100MB.bin', size: '100 MB' },
      { name: '1 GB', file: '1GB.bin', size: '1 GB' }
    ]
  }
};
```

### 5. Add Device Configuration

Create `config/devices.yaml`:

```yaml
routers:
  - name: core-router-1
    address: 10.0.0.1
    network:
      name: Moscow DC
      display_name: Moscow
    credential:
      username: lookinglass
      password: secret
    platform: cisco_ios
    commands:
      - bgp_route
      - ping
      - traceroute
```

### 6. Start Services

```bash
docker compose up -d
```

### 7. Access the Looking Glass

Open `https://lg.example.com` (your domain from .env)

## Architecture

```
Internet
    │
    ▼ (443/tcp, 80/tcp)
┌─────────────────────────────────────────────┐
│  Caddy (Reverse Proxy)                      │
│  - Automatic HTTPS (Let's Encrypt)          │
│  - HTTP/3 support                           │
└─────────────────────────────────────────────┘
    │                           │
    ▼ (8001/tcp)                ▼ (8080/tcp)
┌──────────────────┐    ┌──────────────────┐
│  hyperglass      │    │  nginx           │
│  (Looking Glass) │    │  (Speed Test)    │
└──────────────────┘    └──────────────────┘
           │
           ▼
    ┌──────────────────┐
    │  Redis           │
    │  (State/Cache)   │
    └──────────────────┘
```

## Ports

| Port | Binding | Service | Description |
|------|---------|---------|-------------|
| 80 | Public | Caddy | HTTP (redirects to HTTPS) |
| 443 | Public | Caddy | HTTPS main entry point |
| 8001 | localhost | hyperglass | Looking glass web UI |
| 8080 | localhost | nginx | Speed test file downloads |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LG_DOMAIN` | `lg.example.com` | Your domain for HTTPS |
| `LG_EMAIL` | `admin@example.com` | Email for Let's Encrypt |
| `HYPERGLASS_APP_PATH` | `/etc/hyperglass` | Configuration directory |
| `HYPERGLASS_PORT` | `8001` | Hyperglass port |
| `HYPERGLASS_REDIS_HOST` | `redis` | Redis hostname |

## systemd Service (Optional)

Create a systemd service for auto-start:

```bash
cat > /etc/systemd/system/looking-glass.service << 'EOF'
[Unit]
Description=Multi-location Looking Glass
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/hyperglass/docker
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable looking-glass
systemctl start looking-glass
```

## Customization

### Adding More Speed Test Files

Mount a custom speedtest directory:

```yaml
volumes:
  - ./my-speedtest-files:/var/www/speedtest:ro
```

### Custom Branding

Edit the theme in `config/hyperglass.yaml`:

```yaml
web:
  theme:
    colors:
      primary: "#your-brand-color"
    fonts:
      body: "Your Font"
  logo:
    light: /etc/hyperglass/images/logo-light.png
    dark: /etc/hyperglass/images/logo-dark.png
```

### Modifying the Navigation Bar

Edit the `theme` object in your `config/custom/custom_ui.js`:

```javascript
theme: {
  navBarBg: '#1a202c',
  accentColor: '#your-brand-color'
}
```

## Troubleshooting

### Check Container Logs

```bash
docker compose logs -f looking-glass
docker compose logs -f caddy
```

### Verify Caddy Configuration

```bash
docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile
```

### Test Speed Test Files

```bash
curl -I https://lg.example.com/speedtest/10MB.bin
```

### Check Certificate Status

```bash
docker compose exec caddy caddy list-certs
```

### Restart Services

```bash
docker compose restart
```

### Full Rebuild

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

## GitHub Container Registry

Pull pre-built images:

```bash
docker pull ghcr.io/dignezzz/hyperglass:latest
```

## License

Based on [hyperglass](https://github.com/thatmattlove/hyperglass) - BSD 3-Clause License
