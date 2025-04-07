#!/bin/bash

# Function to check if a package is installed
is_installed() {
  dpkg -l | grep -q "$1"
}

# Function to check if a Docker container is running
is_container_running() {
  docker ps -q --filter "name=$1" | grep -q .
}

# Update package list
echo "Updating package list..."
apt update

# Check and install OpenJDK 17
if is_installed "openjdk-17-jdk"; then
  echo "OpenJDK 17 is already installed."
else
  echo "Installing OpenJDK 17..."
  apt install -y openjdk-17-jdk
fi

# Check and install jq
if is_installed "jq"; then
  echo "jq is already installed."
else
  echo "Installing jq..."
  apt install -y jq
fi

# Check and run Docker registry
if is_container_running "registry"; then
  echo "Docker registry is already running."
else
  echo "Running Docker registry..."
  docker run -d -p 5000:5000 --restart=always --name registry registry:2
fi

# Check and install Helm
if command -v helm &> /dev/null; then
  echo "Helm is already installed."
else
  echo "Helm is not installed! Please install it manually, according to https://helm.sh/docs/intro/install/"
  exit 1
fi

echo "System setup complete."

