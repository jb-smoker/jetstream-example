#!/bin/bash
set -e

# Set logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start Docker
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Pull and run LiteLLM container
docker run -d \
  --name litellm \
  --restart unless-stopped \
  --platform linux/amd64 \
  -p ${litellm_port}:4000 \
  -e OPENAI_API_KEY=${litellm_api_key} \
  ${litellm_image}

# Wait for container to start
sleep 5

# Check if container is running
if ! docker ps | grep -q litellm; then
  echo "Error: LiteLLM container failed to start"
  docker logs litellm
  exit 1
fi

echo "LiteLLM container started successfully on port ${litellm_port}"
