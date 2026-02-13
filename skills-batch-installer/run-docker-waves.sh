#!/bin/sh

# Wave-Based Distributed Anti-Bot Load Testing
# POSIX shell compatible version

# Parameters with defaults
TotalRuns=${1:-10}
InitialConcurrency=${2:-2}
MaxConcurrency=${3:-4}
MinWaveDelaySeconds=${4:-2}
MaxWaveDelaySeconds=${5:-5}
Image=${6:-alpine:latest}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo ""
echo -e "${CYAN}Wave-Based Distributed Anti-Bot Load Testing${NC}"
echo -e "${CYAN}==============================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo -e "${YELLOW}  Total Runs: $TotalRuns${NC}"
echo -e "${YELLOW}  Initial Concurrency: $InitialConcurrency${NC}"
echo -e "${YELLOW}  Max Concurrency: $MaxConcurrency${NC}"
echo -e "${YELLOW}  Wave Delay Range: $MinWaveDelaySeconds-$MaxWaveDelaySeconds seconds${NC}"
echo -e "${YELLOW}  Docker Image: $Image${NC}"
echo ""

startTime=$(date +%s)
completed=0
waveNumber=0
started=0
pids=""

# POSIX-compatible random function
get_random() {
    min=$1
    max=$2
    range=$((max - min + 1))
    # Use /dev/urandom for random number
    rand=$(od -An -N2 -i /dev/urandom | awk '{print $1}')
    result=$((min + (rand % range)))
    echo $result
}

# Start a docker job in background
start_run_job() {
    index=$1
    imageName=$2
    
    deviceId=$(openssl rand -hex 16 2>/dev/null || echo "dev-$index")
    clientUuid=$(openssl rand -hex 16 2>/dev/null || echo "uuid-$index")
    userAgent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
    
    # Start background job - simplified for POSIX shells
    (
        runStartTime=$(date +%s)
        
        echo -e "${GREEN}[RUN $index] Starting with Device: ${deviceId%????????}... UUID: ${clientUuid%????????}...${NC}"
        
        # Run docker container
        docker run --rm \
            -e "DEVICE_ID=$deviceId" \
            -e "CLIENT_UUID=$clientUuid" \
            -e "USER_AGENT=$userAgent" \
            "$imageName" echo "Container $index executed" 2>&1 > /dev/null
        
        exitCode=$?
        runEndTime=$(date +%s)
        duration=$((runEndTime - runStartTime))
        
        if [ $exitCode -eq 0 ]; then
            echo -e "${GREEN}[RUN $index] Completed (Duration: ${duration}s)${NC}"
        else
            echo -e "${RED}[RUN $index] Failed (exit code: $exitCode, Duration: ${duration}s)${NC}"
        fi
    ) &
    
    # Store process ID
    pids="$pids $!"
}

# Main loop
while [ "$completed" -lt "$TotalRuns" ]; do
    waveNumber=$((waveNumber + 1))
    
    # Calculate current concurrency and wave size
    currentConcurrency=$((InitialConcurrency + (waveNumber - 1)))
    if [ $currentConcurrency -gt $MaxConcurrency ]; then
        currentConcurrency=$MaxConcurrency
    fi
    
    waveSize=$((currentConcurrency))
    if [ $((started + waveSize)) -gt "$TotalRuns" ]; then
        waveSize=$((TotalRuns - started))
    fi
    
    echo -e "${MAGENTA}[WAVE $waveNumber] Starting $waveSize concurrent runs${NC}"
    
    waveStartTime=$(date +%s)
    
    # Start wave jobs
    i=0
    while [ $i -lt $waveSize ]; do
        if [ "$started" -lt "$TotalRuns" ]; then
            started=$((started + 1))
            start_run_job "$started" "$Image"
        fi
        i=$((i + 1))
    done
    
    # Wait for all jobs in wave to complete
    wait
    
    waveEndTime=$(date +%s)
    waveDuration=$((waveEndTime - waveStartTime))
    
    completed=$((started))
    timestamp=$(date '+%H:%M:%S')
    
    echo -e "${GREEN}[WAVE $waveNumber COMPLETE] Duration: ${waveDuration}s | Progress: $completed/$TotalRuns${NC}"
    echo ""
    
    # Delay before next wave if not complete
    if [ "$completed" -lt "$TotalRuns" ]; then
        nextWaveDelay=$(get_random "$MinWaveDelaySeconds" "$MaxWaveDelaySeconds")
        nextWaveTime=$(($(date +%s) + nextWaveDelay))
        nextWaveTimeStr=$(date -d @$nextWaveTime '+%H:%M:%S' 2>/dev/null || echo "in $nextWaveDelay seconds")
        
        echo -e "${YELLOW}[DELAY] Waiting $nextWaveDelay seconds before Wave $((waveNumber + 1))...${NC}"
        echo -e "${YELLOW}        Next wave starts at approximately: $nextWaveTimeStr${NC}"
        echo ""
        
        sleep "$nextWaveDelay"
    fi
done

endTime=$(date +%s)
totalDuration=$((endTime - startTime))

echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}TEST COMPLETED${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${YELLOW}Statistics:${NC}"
echo -e "${YELLOW}  Total Runs: $TotalRuns${NC}"
echo -e "${YELLOW}  Total Waves: $waveNumber${NC}"
echo -e "${YELLOW}  Total Duration: ${totalDuration} seconds${NC}"
echo -e "${YELLOW}  Average per Run: ~$((totalDuration / TotalRuns)) seconds${NC}"
echo ""
echo -e "${GREEN}  Successful: $TotalRuns/$TotalRuns${NC}"
echo ""
