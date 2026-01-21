#!/bin/bash
# RepPlusApp Deployment Script

set -e

echo "=== RepPlusApp Deployment ==="

# Navigate to app directory
cd ~/RepPlusApp

# Build and start container
echo "Building Docker image..."
docker-compose build

echo "Starting container..."
docker-compose up -d

echo "Checking status..."
docker ps | grep repplus

echo ""
echo "=== Deployment Complete ==="
echo "App is running on port 3838"
echo "Access via: http://$(curl -s ifconfig.me):3838/repplus/"
