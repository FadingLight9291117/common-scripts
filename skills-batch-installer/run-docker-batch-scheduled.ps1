param(
    [int]$Total = 20,
    [int]$Concurrency = 4,
    [int]$MinDelaySeconds = 1,
    [int]$MaxDelaySeconds = 30,
    [string]$Image = "skills-installer",
    [bool]$Randomize = $true
)

if ($Total -lt 1) {
    Write-Error "Total must be >= 1"
    exit 1
}
if ($Concurrency -lt 1) {
    Write-Error "Concurrency must be >= 1"
    exit 1
}
if ($MinDelaySeconds -lt 0 -or $MaxDelaySeconds -lt 0) {
    Write-Error "Delay values must be >= 0"
    exit 1
}
if ($MinDelaySeconds -gt $MaxDelaySeconds) {
    Write-Error "MinDelaySeconds must be <= MaxDelaySeconds"
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Distributed Anti-Bot Load Testing" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Runs: $Total" -ForegroundColor Yellow
Write-Host "Concurrency: $Concurrency" -ForegroundColor Yellow
Write-Host "Delay Range: $MinDelaySeconds-$MaxDelaySeconds seconds" -ForegroundColor Yellow
Write-Host "Randomization: $Randomize" -ForegroundColor Yellow
Write-Host "Image: $Image" -ForegroundColor Yellow
Write-Host "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$started = 0
$completed = 0
[System.Collections.ArrayList]$jobs = @()
[System.Collections.ArrayList]$completedRuns = @()

function Start-RunJob {
    param([int]$Index, [string]$ImageName)
    
    # Generate unique client identifiers for this run
    $deviceId = [System.Guid]::NewGuid().ToString()
    $clientUuid = [System.Guid]::NewGuid().ToString()
    $userAgents = @(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15",
        "Mozilla/5.0 (Android 11; SM-G991B) AppleWebKit/537.36",
        "Mozilla/5.0 (iPad; CPU OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15"
    )
    $userAgent = $userAgents[$Index % $userAgents.Count]
    
    Start-Job -Name "run-$Index" -ScriptBlock {
        param($i, $img, $devId, $clUuid, $ua)
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] Run $i launched [Device: $($devId.Substring(0,8))... UUID: $($clUuid.Substring(0,8))...]" -ForegroundColor Green
        
        # Run container with different client identities
        & docker run --rm `
            -e "DEVICE_ID=$devId" `
            -e "CLIENT_UUID=$clUuid" `
            -e "USER_AGENT=$ua" `
            $img 2>&1 | Out-Null
        
        $exitCode = $LASTEXITCODE
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        if ($exitCode -eq 0) {
            Write-Host "[$timestamp] Run $i completed successfully" -ForegroundColor Green
        } else {
            Write-Host "[$timestamp] Run $i failed (exit code: $exitCode)" -ForegroundColor Red
        }
        return @{
            Index = $i
            ExitCode = $exitCode
            Timestamp = $timestamp
            DeviceId = $devId
        }
    } -ArgumentList $Index, $ImageName, $deviceId, $clientUuid, $userAgent
}

function Get-RandomDelay {
    param([int]$Min, [int]$Max)
    if ($Min -eq 0 -and $Max -eq 0) {
        return 0
    }
    $random = Get-Random -Minimum $Min -Maximum ($Max + 1)
    return $random
}

$batchCount = 0
$startTime = Get-Date

while ($completed -lt $Total) {
    # Start new jobs if we have capacity
    while ($started -lt $Total -and $jobs.Count -lt $Concurrency) {
        $started++
        $job = Start-RunJob -Index $started -ImageName $Image
        $jobs.Add($job) | Out-Null
    }

    # Wait for at least one job to complete
    if ($jobs.Count -gt 0) {
        $done = Wait-Job -Job $jobs[0]
        $result = Receive-Job -Job $done
        Remove-Job -Job $done
        $jobs.RemoveAt(0)
        $completed++
        
        $completedRuns.Add($result) | Out-Null
        Write-Host "Progress: $completed/$Total completed" -ForegroundColor Yellow
        
        # If more runs remain and we need to introduce delay
        if ($completed -lt $Total -and $completed % $Concurrency -eq 0) {
            if ($Randomize) {
                $delaySeconds = Get-RandomDelay -Min $MinDelaySeconds -Max $MaxDelaySeconds
            } else {
                $delaySeconds = $MinDelaySeconds
            }
            
            if ($delaySeconds -gt 0) {
                $batchCount++
                $nextBatchTime = (Get-Date).AddSeconds($delaySeconds)
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Cyan
                Write-Host "Batch $batchCount completed. Waiting $delaySeconds seconds..." -ForegroundColor Yellow
                Write-Host "Next batch will start at: $($nextBatchTime.ToString('HH:mm:ss'))" -ForegroundColor Yellow
                Write-Host "========================================" -ForegroundColor Cyan
                Write-Host ""
                
                Start-Sleep -Seconds $delaySeconds
            }
        }
    }
}

# Wait for any remaining jobs
while ($jobs.Count -gt 0) {
    $done = Wait-Job -Job $jobs[0]
    $result = Receive-Job -Job $done
    Remove-Job -Job $done
    $jobs.RemoveAt(0)
    $completed++
}

$endTime = Get-Date
$totalDuration = $endTime - $startTime

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Runs: $Total" -ForegroundColor Yellow
Write-Host "Batches: $batchCount" -ForegroundColor Yellow
Write-Host "Start Time: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
Write-Host "End Time: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
$totalSeconds = [math]::Round($totalDuration.TotalSeconds, 2)
Write-Host "Total Duration: $totalSeconds seconds" -ForegroundColor Yellow
Write-Host "Average Time per Run: $([math]::Round($totalDuration.TotalSeconds / $Total, 2)) seconds" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Summary statistics
$successCount = ($completedRuns | Where-Object { $_.ExitCode -eq 0 }).Count
$failureCount = ($completedRuns | Where-Object { $_.ExitCode -ne 0 }).Count
$successPercent = [math]::Round($successCount / $Total * 100, 2)

Write-Host "Success Rate: $successCount/$Total ($successPercent%)" -ForegroundColor Green
if ($failureCount -gt 0) {
    Write-Host "Failures: $failureCount" -ForegroundColor Red
}
