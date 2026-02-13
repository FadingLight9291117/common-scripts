#!/bin/bash
# Syntax validation test for bash scripts

echo "Testing install-skills-quick.sh syntax..."
bash -n ./install-skills-quick.sh
if [ $? -eq 0 ]; then echo "✓ install-skills-quick.sh syntax OK"; else echo "✗ install-skills-quick.sh syntax ERROR"; fi

echo "Testing run-docker-batch-scheduled.sh syntax..."
bash -n ./run-docker-batch-scheduled.sh
if [ $? -eq 0 ]; then echo "✓ run-docker-batch-scheduled.sh syntax OK"; else echo "✗ run-docker-batch-scheduled.sh syntax ERROR"; fi

echo "Testing run-docker-batch.sh syntax..."
bash -n ./run-docker-batch.sh
if [ $? -eq 0 ]; then echo "✓ run-docker-batch.sh syntax OK"; else echo "✗ run-docker-batch.sh syntax ERROR"; fi

echo "Testing run-docker-waves.sh syntax..."
bash -n ./run-docker-waves.sh
if [ $? -eq 0 ]; then echo "✓ run-docker-waves.sh syntax OK"; else echo "✗ run-docker-waves.sh syntax ERROR"; fi

echo ""
echo "All syntax checks completed!"
