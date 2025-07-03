#!/bin/bash

# Stop and remove existing Portainer container if it exists
docker stop portainer 2>/dev/null || true
docker rm portainer 2>/dev/null || true

# Create volume if it doesn't exist
docker volume create portainer_data 2>/dev/null || true

# Run Portainer
docker run -d \
  -p 8000:8000 \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

echo "Portainer has been successfully deployed!"
echo "Access the UI at: https://$(hostname -I | awk '{print $1}'):9443"
echo "or https://localhost:9443 if accessing locally"
