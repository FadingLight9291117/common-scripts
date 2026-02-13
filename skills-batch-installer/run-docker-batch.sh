#!/bin/sh

# Distributed Anti-Bot Load Testing - Concurrent execution
# POSIX shell compatible version

# Parameters with defaults
Total=${1:-20}
Concurrency=${2:-4}
Image=${3:-alpine:latest}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Validation
if [ "$Total" -lt 1 ]; then
    echo -e "${RED}ERROR: Total must be >= 1${NC}" >&2
    exit 1
fi
if [ "$Concurrency" -lt 1 ]; then
    echo -e "${RED}ERROR: Concurrency must be >= 1${NC}" >&2
    exit 1
fi

echo -e "${CYAN}Starting $Total runs with concurrency $Concurrency${NC}"
echo -e "${CYAN}Image: $Image${NC}"
echo -e "${YELLOW}Each container will use a different client identity for anti-bot testing${NC}"

started=0
completed=0

start_run_job() {
    index=$1
    imageName=$2
    
    # Generate unique client identifiers
    deviceId=$(openssl rand -hex 16 2>/dev/null || echo "dev-$index")
    clientUuid=$(openssl rand -hex 16 2>/dev/null || echo "uuid-$index")
    userAgent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
    
    # Start background job
    (
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${GREEN}[$timestamp] Run $index start${NC}"
        
        # Run container with different client identities
        docker run --rm \
            -e "DEVICE_ID=$deviceId" \
            -e "CLIENT_UUID=$clientUuid" \
            -e "USER_AGENT=$userAgent" \
            "$imageName" 2>&1
        
        exitCode=$?
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        if [ $exitCode -eq 0 ]; then
            echo -e "${GREEN}[$timestamp] Run $index success${NC}"
        else
            echo -e "${RED}[$timestamp] Run $index failed (exit $exitCode)${NC}"
        fi
    ) &
    
    echo $!
}

# Main loop
while [ "$completed" -lt "$Total" ]; do
    # Start new jobs if we have capacity
    while [ "$started" -lt "$Total" ] && [ "$(jobs -r | wc -l)" -lt "$Concurrency" ]; do
        started=$((started + 1))
        start_run_job "$started" "$Image" > /dev/null
    done
    
    # Wait for at least one job to complete
    wait -n 2>/dev/null
    completed=$((completed + 1))
    
    echo -e "${YELLOW}Progress: $completed/$Total completed${NC}"
done

echo -e "${GREEN}All runs completed with different client identities.${NC}"