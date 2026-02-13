# Skills Batch Installer - Bash Version

This directory contains both PowerShell and Bash versions of the skills batch installation and load testing scripts.

## Files

### PowerShell Scripts (.ps1)
- `install-skills-quick.ps1` - Install and test skills quickly
- `run-docker-batch.ps1` - Run concurrent Docker containers
- `run-docker-batch-scheduled.ps1` - Run Docker containers with scheduled delays
- `run-docker-waves.ps1` - Run Docker containers in waves with progressive concurrency

### Bash Scripts (.sh)
- `install-skills-quick.sh` - Bash version of install-skills-quick.ps1
- `run-docker-batch.sh` - Bash version of run-docker-batch.ps1
- `run-docker-batch-scheduled.sh` - Bash version of run-docker-batch-scheduled.ps1
- `run-docker-waves.sh` - Bash version of run-docker-waves.ps1

## Usage

### Bash Scripts

Make scripts executable:
```bash
chmod +x *.sh
```

#### install-skills-quick.sh
```bash
./install-skills-quick.sh
```
Installs skills in a temporary directory, then removes them.

#### run-docker-batch.sh
```bash
./run-docker-batch.sh [Total] [Concurrency] [Image]
# Default: ./run-docker-batch.sh 20 4 skills-installer
```
Runs Docker containers concurrently with different client identities.

#### run-docker-batch-scheduled.sh
```bash
./run-docker-batch-scheduled.sh [Total] [Concurrency] [MinDelay] [MaxDelay] [Image] [Randomize]
# Default: ./run-docker-batch-scheduled.sh 20 4 1 30 skills-installer true
```
Runs Docker containers in batches with scheduled delays between batches.

#### run-docker-waves.sh
```bash
./run-docker-waves.sh [TotalRuns] [InitialConcurrency] [MaxConcurrency] [MinWaveDelay] [MaxWaveDelay] [Image]
# Default: ./run-docker-waves.sh 100 2 8 5 60 skills-installer
```
Runs Docker containers in waves with progressive concurrency increase.

## Testing

Run syntax validation:
```bash
bash test-syntax.sh
```

## Cross-Platform Features

Both PowerShell and Bash versions feature:
- Colored output for better readability
- Progress tracking and statistics
- Error handling and logging
- Unique client identifiers (device ID, client UUID, user agent)
- Configurable parameters
- Automatic cleanup

## Requirements

### For Bash scripts:
- bash shell
- Docker
- openssl (for generating random identifiers)
- bc (for calculations in some scripts)
- date command with GNU extensions (or BSD equivalent on macOS)

### For PowerShell scripts:
- PowerShell 5.0+
- Docker
- .NET Framework

## Notes

- All scripts use color-coded output for easy monitoring
- The wave-based script demonstrates progressive load testing strategy
- Anti-bot testing is simulated through different client identities
- Temporary directories are automatically cleaned up
