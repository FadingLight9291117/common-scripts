#!/bin/sh

# Distributed Anti-Bot Load Testing with scheduled delays
# POSIX shell compatible version

# Parameters with defaults
Total=${1:-20}
Concurrency=${2:-4}
MinDelaySeconds=${3:-1}
MaxDelaySeconds=${4:-30}
Image=${5:-alpine:latest}
Randomize=${6:-true}

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
if [ "$MinDelaySeconds" -lt 0 ] || [ "$MaxDelaySeconds" -lt 0 ]; then
    echo -e "${RED}ERROR: Delay values must be >= 0${NC}" >&2
    exit 1
fi
if [ "$MinDelaySeconds" -gt "$MaxDelaySeconds" ]; then
    echo -e "${RED}ERROR: MinDelaySeconds must be <= MaxDelaySeconds${NC}" >&2
    exit 1
fi

echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}Distributed Anti-Bot Load Testing${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${YELLOW}Total Runs: $Total${NC}"
echo -e "${YELLOW}Concurrency: $Concurrency${NC}"
echo -e "${YELLOW}Delay Range: $MinDelaySeconds-$MaxDelaySeconds seconds${NC}"
echo -e "${YELLOW}Randomization: $Randomize${NC}"
echo -e "${YELLOW}Image: $Image${NC}"
echo -e "${YELLOW}Start Time: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

started=0
completed=0
batchCount=0
startTime=$(date +%s)

get_random_delay() {
    min=$1
    max=$2
    if [ "$min" -eq 0 ] && [ "$max" -eq 0 ]; then
        echo 0
        return
    fi
    range=$((max - min + 1))
    rand=$(od -An -N2 -i /dev/urandom | awk '{print $1}')
    result=$((min + (rand % range)))
    echo $result
}

start_run_job() {
    index=$1
    imageName=$2
    
    # Generate unique identifiers
    deviceId=$(openssl rand -hex 16 2>/dev/null || echo "dev-$index")
    clientUuid=$(openssl rand -hex 16 2>/dev/null || echo "uuid-$index")
    userAgent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
    
    # Start background job
    (
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${GREEN}[$timestamp] Run $index launched${NC}"
        
        # Run container with different client identities
        docker run --rm \
            -e "DEVICE_ID=$deviceId" \
            -e "CLIENT_UUID=$clientUuid" \
            -e "USER_AGENT=$userAgent" \
            "$imageName" 2>&1 > /dev/null
        
        exitCode=$?
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        if [ $exitCode -eq 0 ]; then
            echo -e "${GREEN}[$timestamp] Run $index completed successfully${NC}"
        else
            echo -e "${RED}[$timestamp] Run $index failed (exit code: $exitCode)${NC}"
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
    
    # If more runs remain and we need to introduce delay
    if [ "$completed" -lt "$Total" ] && [ $((completed % Concurrency)) -eq 0 ]; then
        if [ "$Randomize" = "true" ]; then
            delaySeconds=$(get_random_delay "$MinDelaySeconds" "$MaxDelaySeconds")
        else
            delaySeconds=$MinDelaySeconds
        fi
        
        if [ "$delaySeconds" -gt 0 ]; then
            batchCount=$((batchCount + 1))
            nextBatchTime=$(date -d "+$delaySeconds seconds" '+%H:%M:%S' 2>/dev/null || echo "in $delaySeconds seconds")
            echo ""
            echo -e "${CYAN}========================================${NC}"
            echo -e "${YELLOW}Batch $batchCount completed. Waiting $delaySeconds seconds...${NC}"
            echo -e "${YELLOW}Next batch will start at: $nextBatchTime${NC}"
            echo -e "${CYAN}========================================${NC}"
            echo ""
            
            sleep "$delaySeconds"
        fi
    fi
done

# Wait for any remaining jobs
wait

endTime=$(date +%s)
totalDuration=$((endTime - startTime))

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}Test Complete!${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${YELLOW}Total Runs: $Total${NC}"
echo -e "${YELLOW}Batches: $batchCount${NC}"
echo -e "${YELLOW}Start Time: $(date -d @$startTime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "(time display not available)")${NC}"
echo -e "${YELLOW}End Time: $(date -d @$endTime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "(time display not available)")${NC}"
echo -e "${YELLOW}Total Duration: $totalDuration seconds${NC}"
echo -e "${YELLOW}Average Time per Run: $((totalDuration / Total)) seconds${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
