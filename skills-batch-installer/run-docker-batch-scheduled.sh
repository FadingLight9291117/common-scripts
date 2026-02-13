#!/bin/bash

# Distributed Anti-Bot Load Testing with scheduled delays

# Parameters with defaults
Total=${1:-20}
Concurrency=${2:-4}
MinDelaySeconds=${3:-1}
MaxDelaySeconds=${4:-30}
Image=${5:-skills-installer}
Randomize=${6:-true}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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
declare -a jobs
declare -a completedRuns
startTime=$(date +%s)

function get_random_delay() {
    local min=$1
    local max=$2
    if [ "$min" -eq 0 ] && [ "$max" -eq 0 ]; then
        echo 0
        return
    fi
    echo $((RANDOM % (max - min + 1) + min))
}

function start_run_job() {
    local index=$1
    local imageName=$2
    
    # Generate unique identifiers
    local deviceId=$(openssl rand -hex 16)
    local clientUuid=$(openssl rand -hex 16)
    local userAgents=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
        "Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15"
        "Mozilla/5.0 (Android 11; SM-G991B) AppleWebKit/537.36"
        "Mozilla/5.0 (iPad; CPU OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15"
    )
    local userAgent=${userAgents[$((index % ${#userAgents[@]}))}
    
    # Start background job
    {
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        deviceIdShort=${deviceId:0:8}
        clientUuidShort=${clientUuid:0:8}
        echo -e "${GREEN}[$timestamp] Run $index launched [Device: ${deviceIdShort}... UUID: ${clientUuidShort}...]${NC}"
        
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
        
        echo "$index:$exitCode:$timestamp:${deviceIdShort}"
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
        
        # If more runs remain and we need to introduce delay
        if [ "$completed" -lt "$Total" ] && [ $((completed % Concurrency)) -eq 0 ]; then
            if [ "$Randomize" = true ]; then
                delaySeconds=$(get_random_delay "$MinDelaySeconds" "$MaxDelaySeconds")
            else
                delaySeconds=$MinDelaySeconds
            fi
            
            if [ "$delaySeconds" -gt 0 ]; then
                batchCount=$((batchCount + 1))
                nextBatchTime=$(date -d "+$delaySeconds seconds" '+%H:%M:%S')
                echo ""
                echo -e "${CYAN}========================================${NC}"
                echo -e "${YELLOW}Batch $batchCount completed. Waiting $delaySeconds seconds...${NC}"
                echo -e "${YELLOW}Next batch will start at: $nextBatchTime${NC}"
                echo -e "${CYAN}========================================${NC}"
                echo ""
                
                sleep "$delaySeconds"
            fi
        fi
    fi
done

# Wait for any remaining jobs
for jobPid in "${jobs[@]}"; do
    wait "$jobPid" 2>/dev/null
done

endTime=$(date +%s)
totalDuration=$((endTime - startTime))

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}Test Complete!${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${YELLOW}Total Runs: $Total${NC}"
echo -e "${YELLOW}Batches: $batchCount${NC}"
echo -e "${YELLOW}Start Time: $(date -d @$startTime '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${YELLOW}End Time: $(date -d @$endTime '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${YELLOW}Total Duration: $totalDuration seconds${NC}"
avgTime=$(echo "scale=2; $totalDuration / $Total" | bc)
echo -e "${YELLOW}Average Time per Run: $avgTime seconds${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
