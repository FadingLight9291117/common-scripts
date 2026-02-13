#!/bin/bash

# Wave-Based Distributed Anti-Bot Load Testing

# Parameters with defaults
TotalRuns=${1:-100}
InitialConcurrency=${2:-2}
MaxConcurrency=${3:-8}
MinWaveDelaySeconds=${4:-5}
MaxWaveDelaySeconds=${5:-60}
Image=${6:-skills-installer}

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
declare -a allRuns
declare -a jobs
started=0

function start_run_job() {
    local index=$1
    local imageName=$2
    
    local deviceId=$(openssl rand -hex 16)
    local clientUuid=$(openssl rand -hex 16)
    local userAgents=(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
        'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15'
        'Mozilla/5.0 (Android 11; SM-G991B) AppleWebKit/537.36'
    )
    local userAgent=${userAgents[$((index % ${#userAgents[@]}))]
    
    # Start background job
    {
        runStartTime=$(date +%s%N)
        docker run --rm \
            -e "DEVICE_ID=$deviceId" \
            -e "CLIENT_UUID=$clientUuid" \
            -e "USER_AGENT=$userAgent" \
            "$imageName" 2>&1 > /dev/null
        
        runEndTime=$(date +%s%N)
        duration=$(echo "scale=2; ($runEndTime - $runStartTime) / 1000000000" | bc)
        
        echo "$index:$?:$duration"
    } &
    
    echo $!
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
    for ((i = 0; i < waveSize; i++)); do
        if [ "$started" -lt "$TotalRuns" ]; then
            started=$((started + 1))
            jobPid=$(start_run_job "$started" "$Image")
            jobs+=("$jobPid")
        fi
    done
    
    # Wait for all jobs in wave to complete
    while [ ${#jobs[@]} -gt 0 ]; do
        firstJob=${jobs[0]}
        wait "$firstJob" 2>/dev/null
        
        # Remove from jobs array
        jobs=("${jobs[@]:1}")
        completed=$((completed + 1))
        
        timestamp=$(date '+%H:%M:%S')
        echo -e "${GREEN}  [$timestamp] Run completed | Progress: $completed/$TotalRuns${NC}"
    done
    
    waveEndTime=$(date +%s)
    waveDuration=$((waveEndTime - waveStartTime))
    
    echo -e "${GREEN}[WAVE $waveNumber COMPLETE] Duration: ${waveDuration}s${NC}"
    echo ""
    
    # Delay before next wave if not complete
    if [ "$completed" -lt "$TotalRuns" ]; then
        nextWaveDelay=$((RANDOM % (MaxWaveDelaySeconds - MinWaveDelaySeconds + 1) + MinWaveDelaySeconds))
        nextWaveTime=$(date -d "+$nextWaveDelay seconds" '+%H:%M:%S')
        
        echo -e "${YELLOW}[DELAY] Waiting $nextWaveDelay seconds before Wave $((waveNumber + 1))...${NC}"
        echo -e "${YELLOW}        Next wave starts at: $nextWaveTime${NC}"
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
avgPerRun=$(echo "scale=2; $totalDuration / $TotalRuns" | bc)
echo -e "${YELLOW}  Average per Run: $avgPerRun seconds${NC}"
echo ""
echo -e "${YELLOW}Results:${NC}"
echo -e "${GREEN}  Successful: $TotalRuns/$TotalRuns${NC}"
echo ""
