#!/bin/sh

# Bash script: Install skills with configurable interval in random temp directory
# POSIX shell compatible version

# Configuration
skillRepo="https://github.com/fadinglight9291117/arkts_skills"
skills="harmonyos-build-deploy arkts-development"
intervalSeconds=10  # 0 means execute immediately, otherwise wait (in seconds)
maxRuns=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}================================================================${NC}"
echo -e "${GREEN}Skills Auto Installation Script (Temp Directory)${NC}"
echo -e "${CYAN}================================================================${NC}"
echo -e "${YELLOW}Repository: $skillRepo${NC}"
echo -e "${YELLOW}Skills: $skills${NC}"
if [ "$intervalSeconds" -eq 0 ]; then
    echo -e "${YELLOW}Interval: Immediate (no wait)${NC}"
else
    echo -e "${YELLOW}Interval: $intervalSeconds seconds${NC}"
fi
echo -e "${YELLOW}Max Runs: $maxRuns${NC}"
echo -e "${YELLOW}Execution: In random temp directory, deleted after completion${NC}"
echo -e "${CYAN}================================================================\n${NC}"

# Counter
runCount=0

# Loop
while true; do
    runCount=$((runCount + 1))
    
    # Check if max runs reached
    if [ "$maxRuns" -gt 0 ] && [ "$runCount" -gt "$maxRuns" ]; then
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${CYAN}[$timestamp] Completed $maxRuns runs. Script exits.${NC}"
        break
    fi
    
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp] [Run $runCount/$maxRuns] Starting skill installation...${NC}"
    
    {
        # Create random temp directory
        randomId=$(openssl rand -hex 4)
        tempDir="/tmp/skills_test_$randomId"
        
        echo -e "${CYAN}  -> Creating temp directory: $tempDir${NC}"
        mkdir -p "$tempDir"
        
        # Change to temp directory
        cd "$tempDir" || exit 1
        echo -e "${GREEN}    OK Switched to temp directory${NC}"
        
        # Install first skill
        echo -e "${CYAN}  -> Installing: harmonyos-build-deploy${NC}"
        npx skills add "$skillRepo" --skill "harmonyos-build-deploy" --yes &> /dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}    OK harmonyos-build-deploy installed${NC}"
        else
            echo -e "${RED}    ERROR harmonyos-build-deploy failed${NC}"
        fi
        
        # Install second skill
        echo -e "${CYAN}  -> Installing: arkts-development${NC}"
        npx skills add "$skillRepo" --skill "arkts-development" --yes &> /dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}    OK arkts-development installed${NC}"
        else
            echo -e "${RED}    ERROR arkts-development failed${NC}"
        fi
        
        # Remove skills
        echo -e "${CYAN}  -> Removing skills${NC}"
        for skill in $skills; do
            npx skills remove "$skill" --yes &> /dev/null
            if [ $? -eq 0 ] || [ $? -eq 1 ]; then
                echo -e "${GREEN}    OK $skill removed${NC}"
            else
                echo -e "${RED}    ERROR $skill removal failed${NC}"
            fi
        done
        
        # Return to previous directory
        cd - > /dev/null || exit 1
        echo -e "${CYAN}  -> Returned to original directory${NC}"
        
        # Delete temp directory
        echo -e "${CYAN}  -> Deleting temp directory: $tempDir${NC}"
        rm -rf "$tempDir"
        if [ ! -d "$tempDir" ]; then
            echo -e "${GREEN}    OK Temp directory deleted${NC}"
        else
            echo -e "${YELLOW}    WARNING Temp directory still exists${NC}"
        fi
        
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${GREEN}[$timestamp] Run $runCount/$maxRuns completed\n${NC}"
        
    } || {
        echo -e "${RED}    ERROR: Script encountered an error${NC}"
        cd - > /dev/null 2>&1
    }
    
    # Wait for interval before next run (except on last run)
    if [ "$runCount" -lt "$maxRuns" ] && [ "$intervalSeconds" -gt 0 ]; then
        echo -e "${YELLOW}Waiting $intervalSeconds seconds before next run...${NC}"
        sleep "$intervalSeconds"
    fi
done

timestamp=$(date '+%Y-%m-%d %H:%M:%S')
echo -e "\n${GREEN}[$timestamp] All tasks completed!${NC}"
