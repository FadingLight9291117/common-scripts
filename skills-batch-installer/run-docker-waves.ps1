param(
    [int]$TotalRuns = 100,
    [int]$InitialConcurrency = 2,
    [int]$MaxConcurrency = 8,
    [int]$MinWaveDelaySeconds = 5,
    [int]$MaxWaveDelaySeconds = 60,
    [string]$Image = "skills-installer"
)

Write-Host ""
Write-Host "Wave-Based Distributed Anti-Bot Load Testing" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Total Runs: $TotalRuns" -ForegroundColor Yellow
Write-Host "  Initial Concurrency: $InitialConcurrency" -ForegroundColor Yellow
Write-Host "  Max Concurrency: $MaxConcurrency" -ForegroundColor Yellow
Write-Host "  Wave Delay Range: $MinWaveDelaySeconds-$MaxWaveDelaySeconds seconds" -ForegroundColor Yellow
Write-Host "  Docker Image: $Image" -ForegroundColor Yellow
Write-Host ""

$startTime = Get-Date
$completed = 0
$waveNumber = 0
[System.Collections.ArrayList]$allRuns = @()

function Start-RunJob {
    param([int]$Index, [string]$ImageName)
    
    $deviceId = [System.Guid]::NewGuid().ToString()
    $clientUuid = [System.Guid]::NewGuid().ToString()
    $userAgents = @(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
        'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15',
        'Mozilla/5.0 (Android 11; SM-G991B) AppleWebKit/537.36'
    )
    $userAgent = $userAgents[$Index % $userAgents.Count]
    
    Start-Job -Name "run-$Index" -ScriptBlock {
        param($i, $img, $devId, $clUuid, $ua)
        $runStartTime = Get-Date
        & docker run --rm `
            -e "DEVICE_ID=$devId" `
            -e "CLIENT_UUID=$clUuid" `
            -e "USER_AGENT=$ua" `
            $img 2>&1 | Out-Null
        
        return @{
            Index = $i
            ExitCode = $LASTEXITCODE
            Duration = ((Get-Date) - $runStartTime).TotalSeconds
            DeviceId = $devId
        }
    } -ArgumentList $Index, $ImageName, $deviceId, $clientUuid, $userAgent
}

[System.Collections.ArrayList]$jobs = @()
$started = 0

while ($completed -lt $TotalRuns) {
    $waveNumber++
    
    $currentConcurrency = [Math]::Min($InitialConcurrency + ($waveNumber - 1), $MaxConcurrency)
    $waveSize = [Math]::Min($currentConcurrency, $TotalRuns - $started)
    
    Write-Host "[WAVE $waveNumber] Starting $waveSize concurrent runs" -ForegroundColor Magenta
    
    $waveStartTime = Get-Date
    
    for ($i = 0; $i -lt $waveSize; $i++) {
        if ($started -lt $TotalRuns) {
            $started++
            $job = Start-RunJob -Index $started -ImageName $Image
            $jobs.Add($job) | Out-Null
        }
    }
    
    while ($jobs.Count -gt 0) {
        $done = Wait-Job -Job $jobs[0]
        $result = Receive-Job -Job $done
        Remove-Job -Job $done
        $jobs.RemoveAt(0)
        $completed++
        
        $allRuns.Add($result) | Out-Null
        
        $timestamp = Get-Date -Format "HH:mm:ss"
        Write-Host "  [$timestamp] Run $($result.Index) done (Duration: $([Math]::Round($result.Duration, 2))s) | Progress: $completed/$TotalRuns" -ForegroundColor Green
    }
    
    $waveEndTime = Get-Date
    $waveDuration = $waveEndTime - $waveStartTime
    
    Write-Host "[WAVE $waveNumber COMPLETE] Duration: $([Math]::Round($waveDuration.TotalSeconds, 2))s" -ForegroundColor Green
    Write-Host ""
    
    if ($completed -lt $TotalRuns) {
        $nextWaveDelay = Get-Random -Minimum $MinWaveDelaySeconds -Maximum ($MaxWaveDelaySeconds + 1)
        $nextWaveTime = (Get-Date).AddSeconds($nextWaveDelay)
        
        Write-Host "[DELAY] Waiting $nextWaveDelay seconds before Wave $($waveNumber + 1)..." -ForegroundColor Yellow
        Write-Host "        Next wave starts at: $($nextWaveTime.ToString('HH:mm:ss'))" -ForegroundColor Yellow
        Write-Host ""
        
        Start-Sleep -Seconds $nextWaveDelay
    }
}

$endTime = Get-Date
$totalDuration = $endTime - $startTime

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TEST COMPLETED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Statistics:" -ForegroundColor Yellow
Write-Host "  Total Runs: $TotalRuns" -ForegroundColor Yellow
Write-Host "  Total Waves: $waveNumber" -ForegroundColor Yellow
Write-Host "  Total Duration: $([Math]::Round($totalDuration.TotalSeconds, 2)) seconds" -ForegroundColor Yellow
Write-Host "  Average per Run: $([Math]::Round($totalDuration.TotalSeconds / $TotalRuns, 2)) seconds" -ForegroundColor Yellow
Write-Host ""

$successCount = ($allRuns | Where-Object { $_.ExitCode -eq 0 }).Count
$failureCount = $TotalRuns - $successCount

Write-Host "Results:" -ForegroundColor Yellow
Write-Host "  Successful: $successCount/$TotalRuns" -ForegroundColor Green
if ($failureCount -gt 0) {
    Write-Host "  Failed: $failureCount/$TotalRuns" -ForegroundColor Red
}
Write-Host ""
