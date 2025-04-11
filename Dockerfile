FROM python:3.12-slim

WORKDIR /app/OpenManus

# Install system dependencies and clean up in a single layer to reduce image size
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv package manager
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Copy requirements first to leverage Docker cache
COPY requirements.txt .

# Install Python dependencies
RUN . ~/.cargo/env && uv pip install --system -r requirements.txt

# Install browser automation tools if needed
RUN pip install playwright && \
    playwright install --with-deps chromium

# Copy application code
COPY . .

# Create necessary directories with proper permissions
RUN mkdir -p config data && \
    chmod -R 755 /app/OpenManus

# Create a default config file if one doesn't exist
RUN if [ ! -f config/config.toml ]; then \
    cp config/config.example.toml config/config.toml; \
    fi

# Add a wrapper script to handle environment variables
COPY <<'EOF' /app/OpenManus/docker-entrypoint.sh
#!/bin/bash
set -e

# If OPENAI_API_KEY is set, update the config file
if [ -n "$OPENAI_API_KEY" ]; then
    sed -i "s|api_key = \"sk-.*\"|api_key = \"$OPENAI_API_KEY\"|g" config/config.toml
fi

# Pass all arguments to the Python script
exec "$@"
EOF

RUN chmod +x /app/OpenManus/docker-entrypoint.sh

# Use the entrypoint script to configure the application
ENTRYPOINT ["/app/OpenManus/docker-entrypoint.sh"]

# Set default command to run the application
CMD ["python", "main.py"]
