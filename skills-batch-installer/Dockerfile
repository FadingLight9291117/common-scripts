# Use Node.js 18+ as base image
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Install required tools
RUN apk add --no-cache \
    git \
    curl \
    openssl \
    bash \
    bc \
    jq \
    wget \
    ca-certificates

# Copy scripts
COPY install-skills-quick.sh /app/
COPY http-load-test.sh /app/

# Make scripts executable
RUN chmod +x /app/install-skills-quick.sh /app/http-load-test.sh

# Create logs directory
RUN mkdir -p /app/logs

# Accept environment variables for anti-bot testing (different client identities)
ENV DEVICE_ID=""
ENV CLIENT_UUID=""
ENV USER_AGENT=""
ENV TARGET_URL=""
ENV REQUEST_METHOD="GET"
ENV TOTAL_REQUESTS="10"
ENV CONCURRENT_REQUESTS="2"
ENV REQUEST_DELAY_MIN="0.5"
ENV REQUEST_DELAY_MAX="2"
ENV TEST_TYPE="skills"

# Run the appropriate script based on TEST_TYPE
CMD ["sh", "-c", "if [ \"$TEST_TYPE\" = \"http\" ]; then \
        /bin/bash /app/http-load-test.sh; \
    else \
        DEVICE_ID=$DEVICE_ID CLIENT_UUID=$CLIENT_UUID USER_AGENT=$USER_AGENT /bin/bash /app/install-skills-quick.sh; \
    fi && cat /app/logs/*.log 2>/dev/null | tail -100"]

