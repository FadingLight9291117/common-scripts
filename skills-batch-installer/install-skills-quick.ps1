# PowerShell script: Install skills with configurable interval in random temp directory

# Configuration
$skillRepo = "https://github.com/fadinglight9291117/arkts_skills"
$skills = @("harmonyos-build-deploy", "arkts-development")
$intervalSeconds = 10  # 0 means execute immediately, otherwise wait (in seconds)
$maxRuns = 1

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Skills Auto Installation Script (Temp Directory)" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Repository: $skillRepo" -ForegroundColor Yellow
Write-Host "Skills: $($skills -join ', ')" -ForegroundColor Yellow
if ($intervalSeconds -eq 0) {
    Write-Host "Interval: Immediate (no wait)" -ForegroundColor Yellow
} else {
    Write-Host "Interval: $intervalSeconds seconds" -ForegroundColor Yellow
}
Write-Host "Max Runs: $maxRuns" -ForegroundColor Yellow
Write-Host "Execution: In random temp directory, deleted after completion" -ForegroundColor Yellow
Write-Host "================================================================`n" -ForegroundColor Cyan

# Counter
$runCount = 0

# Loop
while ($true) {
    $runCount++
    
    # Check if max runs reached
    if ($maxRuns -and $runCount -gt $maxRuns) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] Completed $maxRuns runs. Script exits." -ForegroundColor Cyan
        break
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [Run $runCount/$maxRuns] Starting skill installation..." -ForegroundColor Green
    
    try {
        # Create random temp directory
        $randomId = [System.Guid]::NewGuid().ToString().Substring(0, 8)
        $tempDir = Join-Path -Path $env:TEMP -ChildPath "skills_test_$randomId"
        
        Write-Host "  -> Creating temp directory: $tempDir" -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        # Change to temp directory
        Push-Location $tempDir
        Write-Host "    OK Switched to temp directory" -ForegroundColor Green
        
        # Install first skill
        Write-Host "  -> Installing: harmonyos-build-deploy" -ForegroundColor Cyan
        & npx skills add $skillRepo --skill "harmonyos-build-deploy" --yes 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    OK harmonyos-build-deploy installed" -ForegroundColor Green
        } else {
            Write-Host "    ERROR harmonyos-build-deploy failed" -ForegroundColor Red
        }
        
        # Install second skill
        Write-Host "  -> Installing: arkts-development" -ForegroundColor Cyan
        & npx skills add $skillRepo --skill "arkts-development" --yes 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    OK arkts-development installed" -ForegroundColor Green
        } else {
            Write-Host "    ERROR arkts-development failed" -ForegroundColor Red
        }
        
        # Remove skills
        Write-Host "  -> Removing skills" -ForegroundColor Cyan
        foreach ($skill in $skills) {
            & npx skills remove $skill --yes 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
                Write-Host "    OK $skill removed" -ForegroundColor Green
            } else {
                Write-Host "    ERROR $skill removal failed" -ForegroundColor Red
            }
        }
        
        # Return to original directory
        Pop-Location
        Write-Host "  -> Returned to original directory" -ForegroundColor Cyan
        
        # Delete temp directory
        Write-Host "  -> Deleting temp directory: $tempDir" -ForegroundColor Cyan
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $tempDir)) {
            Write-Host "    OK Temp directory deleted" -ForegroundColor Green
        } else {
            Write-Host "    WARNING Temp directory still exists" -ForegroundColor Yellow
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] Run $runCount/$maxRuns completed`n" -ForegroundColor Green
        
    } catch {
        Write-Host "    ERROR: $_" -ForegroundColor Red
        # Ensure we return to original directory even if error occurs
        Pop-Location -ErrorAction SilentlyContinue
    }
    
    # Wait for interval before next run (except on last run)
    if ($runCount -lt $maxRuns -and $intervalSeconds -gt 0) {
        Write-Host "Waiting $intervalSeconds seconds before next run..." -ForegroundColor Yellow
        Start-Sleep -Seconds $intervalSeconds
    }
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "`n[$timestamp] All tasks completed!" -ForegroundColor Green
