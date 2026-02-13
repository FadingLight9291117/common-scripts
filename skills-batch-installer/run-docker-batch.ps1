param(
    [int]$Total = 20,
    [int]$Concurrency = 4,
    [string]$Image = "skills-installer"
)

if ($Total -lt 1) {
    Write-Error "Total must be >= 1"
    exit 1
}
if ($Concurrency -lt 1) {
    Write-Error "Concurrency must be >= 1"
    exit 1
}

Write-Host "Starting $Total runs with concurrency $Concurrency" -ForegroundColor Cyan
Write-Host "Image: $Image" -ForegroundColor Cyan
Write-Host "Each container will use a different client identity for anti-bot testing" -ForegroundColor Yellow

$started = 0
$completed = 0
[System.Collections.ArrayList]$jobs = @()

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
        "Mozilla/5.0 (Android 11; SM-G991B) AppleWebKit/537.36"
    )
    $userAgent = $userAgents[$Index % $userAgents.Count]
    
    Start-Job -Name "run-$Index" -ScriptBlock {
        param($i, $img, $devId, $clUuid, $ua)
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] Run $i start [Device: $($devId.Substring(0,8))... UUID: $($clUuid.Substring(0,8))...]" -ForegroundColor Green
        
        # Run container with different client identities
        & docker run --rm `
            -e "DEVICE_ID=$devId" `
            -e "CLIENT_UUID=$clUuid" `
            -e "USER_AGENT=$ua" `
            $img 2>&1
        
        $exitCode = $LASTEXITCODE
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        if ($exitCode -eq 0) {
            Write-Host "[$timestamp] Run $i success" -ForegroundColor Green
        } else {
            Write-Host "[$timestamp] Run $i failed (exit $exitCode)" -ForegroundColor Red
        }
        return $exitCode
    } -ArgumentList $Index, $ImageName, $deviceId, $clientUuid, $userAgent
}

while ($completed -lt $Total) {
    while ($started -lt $Total -and $jobs.Count -lt $Concurrency) {
        $started++
        $job = Start-RunJob -Index $started -ImageName $Image
        $jobs.Add($job) | Out-Null
    }

    if ($jobs.Count -gt 0) {
        $done = Wait-Job -Job $jobs[0]
        Receive-Job -Job $done | Out-Host
        Remove-Job -Job $done
        $jobs.RemoveAt(0)
        $completed++
        Write-Host "Progress: $completed/$Total completed" -ForegroundColor Yellow
    }
}

Write-Host "All runs completed with different client identities." -ForegroundColor Green
