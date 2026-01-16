#!/bin/bash
# =============================================================================
# Quick Setup Script for Multi-location Looking Glass
# Run this script on each server to set up a Looking Glass instance
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Multi-location Looking Glass - Quick Setup               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# =============================================================================
# Gather Information
# =============================================================================

echo -e "${YELLOW}Step 1: Basic Configuration${NC}"
echo ""

# Domain
read -p "Enter domain for this Looking Glass (e.g., lg-msk.example.com): " LG_DOMAIN
if [ -z "$LG_DOMAIN" ]; then
    echo -e "${RED}Error: Domain is required${NC}"
    exit 1
fi

# Email for Let's Encrypt
read -p "Enter email for Let's Encrypt certificates: " LG_EMAIL
if [ -z "$LG_EMAIL" ]; then
    LG_EMAIL="admin@${LG_DOMAIN#*.}"
    echo -e "${YELLOW}Using default email: $LG_EMAIL${NC}"
fi

# Current location ID
echo ""
echo -e "${YELLOW}Step 2: Location Configuration${NC}"
echo ""
read -p "Enter location ID for this server (e.g., moscow, amsterdam, frankfurt): " CURRENT_LOCATION
if [ -z "$CURRENT_LOCATION" ]; then
    echo -e "${RED}Error: Location ID is required${NC}"
    exit 1
fi

# Location display name
read -p "Enter display name (e.g., 'Moscow, RU'): " LOCATION_NAME
if [ -z "$LOCATION_NAME" ]; then
    LOCATION_NAME="$CURRENT_LOCATION"
fi

# Flag emoji
read -p "Enter flag emoji (e.g., 🇷🇺): " LOCATION_FLAG
if [ -z "$LOCATION_FLAG" ]; then
    LOCATION_FLAG="📍"
fi

# Organization name
echo ""
echo -e "${YELLOW}Step 3: Organization Info${NC}"
echo ""
read -p "Enter your organization name: " ORG_NAME
if [ -z "$ORG_NAME" ]; then
    ORG_NAME="My Hosting"
fi

read -p "Enter your primary ASN (e.g., 12345): " PRIMARY_ASN
if [ -z "$PRIMARY_ASN" ]; then
    PRIMARY_ASN="65001"
fi

# =============================================================================
# Configure All Locations
# =============================================================================

echo ""
echo -e "${YELLOW}Step 4: Configure All Locations${NC}"
echo ""
echo "Now enter ALL your locations (including this one)."
echo "Format: id|name|url|flag"
echo "Example: moscow|Moscow, RU|https://lg-msk.example.com|🇷🇺"
echo ""
echo "Enter locations one per line. Press Enter on empty line when done:"
echo ""

LOCATIONS_JSON="["
FIRST=true

while true; do
    read -p "> " location_line
    
    if [ -z "$location_line" ]; then
        break
    fi
    
    # Parse location line
    IFS='|' read -r loc_id loc_name loc_url loc_flag <<< "$location_line"
    
    if [ -z "$loc_id" ] || [ -z "$loc_url" ]; then
        echo -e "${RED}Invalid format. Use: id|name|url|flag${NC}"
        continue
    fi
    
    # Set defaults
    [ -z "$loc_name" ] && loc_name="$loc_id"
    [ -z "$loc_flag" ] && loc_flag="📍"
    
    # Add to JSON
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        LOCATIONS_JSON+=","
    fi
    
    LOCATIONS_JSON+="
    {
      \"id\": \"$loc_id\",
      \"name\": \"$loc_name\",
      \"url\": \"$loc_url\",
      \"flag\": \"$loc_flag\"
    }"
    
    echo -e "${GREEN}Added: $loc_name ($loc_url)${NC}"
done

LOCATIONS_JSON+="
  ]"

# If no locations entered, use default with current
if [ "$FIRST" = true ]; then
    echo -e "${YELLOW}No locations entered. Using only current location.${NC}"
    LOCATIONS_JSON="[
    {
      \"id\": \"$CURRENT_LOCATION\",
      \"name\": \"$LOCATION_NAME\",
      \"url\": \"https://$LG_DOMAIN\",
      \"flag\": \"$LOCATION_FLAG\"
    }
  ]"
fi

# =============================================================================
# Create Configuration Files
# =============================================================================

echo ""
echo -e "${BLUE}Creating configuration files...${NC}"

DOCKER_DIR="/opt/hyperglass/docker"
CONFIG_DIR="$DOCKER_DIR/config"

mkdir -p "$CONFIG_DIR/custom"
mkdir -p "$CONFIG_DIR/images"

# Create .env file
cat > "$DOCKER_DIR/.env" << EOF
# Looking Glass Configuration
# Generated on $(date)

LG_DOMAIN=$LG_DOMAIN
LG_EMAIL=$LG_EMAIL
EOF

echo -e "${GREEN}✓ Created .env${NC}"

# Create hyperglass.yaml
cat > "$CONFIG_DIR/hyperglass.yaml" << EOF
# =============================================================================
# hyperglass Configuration
# Generated on $(date)
# Location: $LOCATION_NAME
# =============================================================================

site_title: "Looking Glass - $LOCATION_NAME"
org_name: "$ORG_NAME"
primary_asn: $PRIMARY_ASN
request_timeout: 90

web:
  custom_javascript: /etc/hyperglass/custom/custom_ui.js
  location_display_mode: dropdown
  
  greeting:
    enable: true
    title: "Network Looking Glass"
    content: |
      Query our network routers for BGP routes, ping, and traceroute.
      Use the navigation bar above to switch between datacenter locations.
      Download test files to measure your connection speed.

  theme:
    default_color_mode: system
    
  credit:
    enable: true

cache:
  timeout: 120

structured:
  rpki:
    mode: cloudflare
EOF

echo -e "${GREEN}✓ Created hyperglass.yaml${NC}"

# Create custom_ui.js with locations config
cat > "$CONFIG_DIR/custom/custom_ui.js" << EOF
/**
 * Multi-location Looking Glass Configuration
 * Generated on $(date)
 * Current Location: $CURRENT_LOCATION ($LOCATION_NAME)
 */

window.LOOKING_GLASS_CONFIG = {
  currentLocation: '$CURRENT_LOCATION',
  
  locations: $LOCATIONS_JSON,
  
  speedTest: {
    enabled: true,
    title: 'Speed Test Downloads',
    description: 'Download test files to measure your connection speed to $LOCATION_NAME',
    baseUrl: '/speedtest',
    files: [
      { name: '10 MB', file: '10MB.bin', size: '10 MB' },
      { name: '100 MB', file: '100MB.bin', size: '100 MB' },
      { name: '1 GB', file: '1GB.bin', size: '1 GB' }
    ]
  },
  
  theme: {
    navBarBg: '#1a202c',
    navBarBgLight: '#ffffff',
    navBarText: '#ffffff',
    navBarTextLight: '#1a202c',
    accentColor: '#3182ce',
    speedTestBg: '#2d3748',
    speedTestBgLight: '#edf2f7'
  }
};

EOF

# Append the main custom_ui.js script
cat "$DOCKER_DIR/custom_ui.js" >> "$CONFIG_DIR/custom/custom_ui.js"

echo -e "${GREEN}✓ Created custom_ui.js${NC}"

# Create sample devices.yaml
cat > "$CONFIG_DIR/devices.yaml" << EOF
# =============================================================================
# Device Configuration
# Add your network devices here
# Documentation: https://hyperglass.dev/configuration/devices
# =============================================================================

routers:
  # Example router - replace with your actual devices
  - name: example-router
    address: 192.168.1.1
    network:
      name: $LOCATION_NAME
      display_name: $LOCATION_NAME
    credential:
      username: lookinglass
      password: your_password_here
    platform: cisco_ios  # See https://hyperglass.dev/platforms
    # Available commands:
    # - bgp_route
    # - bgp_aspath
    # - bgp_community
    # - ping
    # - traceroute
EOF

echo -e "${GREEN}✓ Created devices.yaml (edit with your router details!)${NC}"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Configuration Summary:${NC}"
echo "  Domain:       https://$LG_DOMAIN"
echo "  Location:     $LOCATION_NAME ($CURRENT_LOCATION)"
echo "  Organization: $ORG_NAME"
echo "  ASN:          $PRIMARY_ASN"
echo ""
echo -e "${YELLOW}Files Created:${NC}"
echo "  $DOCKER_DIR/.env"
echo "  $CONFIG_DIR/hyperglass.yaml"
echo "  $CONFIG_DIR/custom/custom_ui.js"
echo "  $CONFIG_DIR/devices.yaml"
echo ""
echo -e "${RED}IMPORTANT: Edit devices.yaml with your actual router details!${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "  1. Edit your devices:"
echo "     nano $CONFIG_DIR/devices.yaml"
echo ""
echo "  2. Start the Looking Glass:"
echo "     cd $DOCKER_DIR && docker compose up -d"
echo ""
echo "  3. Check logs:"
echo "     docker compose logs -f"
echo ""
echo "  4. Open in browser:"
echo "     https://$LG_DOMAIN"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
