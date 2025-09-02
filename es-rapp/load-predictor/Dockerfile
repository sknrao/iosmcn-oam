# Use an official Python runtime as base image
FROM python:3.9-slim

# # Metadata
# LABEL maintainer="Your Name <you@example.com>"
# LABEL description="Flask + TensorFlow model prediction service"

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy your code and model data (e.g., load_test.csv) into the container
COPY . .

# Install required Python packages
RUN pip install --no-cache-dir \
    flask \
    pandas \
    numpy \
    tensorflow-cpu==2.18.0 \
    keras

# Set the entry point
CMD ["python", "prediction_rapp_v1.py"]
