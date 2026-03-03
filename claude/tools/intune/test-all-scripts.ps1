Write-Host "Testing All Intune Reporter Scripts" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

$scripts = @(
    "Run-OrroReport.ps1",
    "Get-IntuneOrroReport.ps1"
)

$allPassed = $true

foreach ($script in $scripts) {
    Write-Host "Testing $script..." -NoNewline

    if (-not (Test-Path $script)) {
        Write-Host " SKIP (not found)" -ForegroundColor Yellow
        continue
    }

    try {
        $content = Get-Content $script -Raw
        $null = [ScriptBlock]::Create($content)
        Write-Host " PASS" -ForegroundColor Green
    } catch {
        Write-Host " FAIL" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
        $allPassed = $false
    }
}

Write-Host ""
if ($allPassed) {
    Write-Host "All scripts passed syntax validation!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ready to use. Run with:" -ForegroundColor Cyan
    Write-Host "  .\Run-OrroReport.ps1" -ForegroundColor White
} else {
    Write-Host "Some scripts have syntax errors!" -ForegroundColor Red
    exit 1
}
