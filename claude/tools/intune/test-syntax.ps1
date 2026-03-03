$content = Get-Content ".\Run-OrroReport.ps1" -Raw
Write-Host "Testing Run-OrroReport.ps1 syntax..." -ForegroundColor Cyan
Write-Host ""

try {
    $sb = [ScriptBlock]::Create($content)
    Write-Host "SUCCESS: No syntax errors found!" -ForegroundColor Green
    Write-Host ""
    Write-Host "The script is valid and ready to run." -ForegroundColor White
    Write-Host ""
    Write-Host "To execute it:" -ForegroundColor Cyan
    Write-Host "  .\Run-OrroReport.ps1" -ForegroundColor White
    exit 0
} catch {
    Write-Host "ERROR: Syntax error found!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    exit 1
}
