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

# Write LiteLLM config file
cat <<EOF > /home/ubuntu/config.yaml
model_list:
  - model_name: gpt-3.5-turbo
    litellm_params:
      model: openai/gpt-3.5-turbo
  - model_name: gpt-5-search-api-2025-10-14
    litellm_params:
      model: openai/gpt-5-search-api-2025-10-14
  - model_name: gpt-audio-mini-2025-10-06
    litellm_params:
      model: openai/gpt-audio-mini-2025-10-06
  - model_name: gpt-5-search-api
    litellm_params:
      model: openai/gpt-5-search-api
  - model_name: sora-2
    litellm_params:
      model: openai/sora-2
  - model_name: sora-2-pro
    litellm_params:
      model: openai/sora-2-pro
  - model_name: davinci-002
    litellm_params:
      model: openai/davinci-002
  - model_name: babbage-002
    litellm_params:
      model: openai/babbage-002
  - model_name: gpt-3.5-turbo-instruct
    litellm_params:
      model: openai/gpt-3.5-turbo-instruct
  - model_name: gpt-3.5-turbo-instruct-0914
    litellm_params:
      model: openai/gpt-3.5-turbo-instruct-0914
  - model_name: dall-e-3
    litellm_params:
      model: openai/dall-e-3
  - model_name: dall-e-2
    litellm_params:
      model: openai/dall-e-2
  - model_name: gpt-3.5-turbo-1106
    litellm_params:
      model: openai/gpt-3.5-turbo-1106
  - model_name: tts-1-hd
    litellm_params:
      model: openai/tts-1-hd
  - model_name: tts-1-1106
    litellm_params:
      model: openai/tts-1-1106
  - model_name: tts-1-hd-1106
    litellm_params:
      model: openai/tts-1-hd-1106
  - model_name: text-embedding-3-small
    litellm_params:
      model: openai/text-embedding-3-small
  - model_name: text-embedding-3-large
    litellm_params:
      model: openai/text-embedding-3-large
  - model_name: gpt-3.5-turbo-0125
    litellm_params:
      model: openai/gpt-3.5-turbo-0125
  - model_name: gpt-4o
    litellm_params:
      model: openai/gpt-4o
EOF

# Pull and run LiteLLM container
docker run -d \
  --name litellm \
  --restart unless-stopped \
  --platform linux/amd64 \
  -p ${litellm_port}:4000 \
  -e OPENAI_API_KEY=${litellm_api_key} \
  -v /home/ubuntu/config.yaml:/app/config.yaml \
  ${litellm_image} --config /app/config.yaml

# Wait for container to start
sleep 5

# Check if container is running
if ! docker ps | grep -q litellm; then
  echo "Error: LiteLLM container failed to start"
  docker logs litellm
  exit 1
fi

echo "LiteLLM container started successfully on port ${litellm_port}"
