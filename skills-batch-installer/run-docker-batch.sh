#!/bin/bash

# Distributed Anti-Bot Load Testing - Concurrent execution

# Parameters with defaults
Total=${1:-20}
Concurrency=${2:-4}
Image=${3:-skills-installer}

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
declare -a jobs

function start_run_job() {
    local index=$1
    local imageName=$2
    
    # Generate unique client identifiers
    local deviceId=$(openssl rand -hex 16)
    local clientUuid=$(openssl rand -hex 16)
    local userAgents=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
        "Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15"
        "Mozilla/5.0 (Android 11; SM-G991B) AppleWebKit/537.36"
    )
    local userAgent=${userAgents[$((index % ${#userAgents[@]}))}
    
    # Start background job
    {
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        deviceIdShort=${deviceId:0:8}
        clientUuidShort=${clientUuid:0:8}
        echo -e "${GREEN}[$timestamp] Run $index start [Device: ${deviceIdShort}... UUID: ${clientUuidShort}...]${NC}"
        
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
    } &
    
    echo $!
}

# Main loop
while [ "$completed" -lt "$Total" ]; do
    # Start new jobs if we have capacity
    while [ "$started" -lt "$Total" ] && [ ${#jobs[@]} -lt "$Concurrency" ]; do
        started=$((started + 1))
        jobPid=$(start_run_job "$started" "$Image")
        jobs+=("$jobPid")
    done
    
    # Wait for at least one job to complete
    if [ ${#jobs[@]} -gt 0 ]; then
        firstJob=${jobs[0]}
        wait "$firstJob" 2>/dev/null
        
        # Remove from jobs array
        jobs=("${jobs[@]:1}")
        completed=$((completed + 1))
        
        echo -e "${YELLOW}Progress: $completed/$Total completed${NC}"
    fi
done

echo -e "${GREEN}All runs completed with different client identities.${NC}"
