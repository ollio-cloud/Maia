# Test script syntax without execution
param(
    [string]$ScriptPath = ".\Run-OrroReport.ps1"
)

Write-Host "Testing PowerShell Script Syntax" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: File exists
Write-Host "[1/4] Checking if file exists..." -NoNewline
if (Test-Path $ScriptPath) {
    Write-Host " ✓" -ForegroundColor Green
} else {
    Write-Host " ✗ File not found: $ScriptPath" -ForegroundColor Red
    exit 1
}

# Test 2: Basic syntax check using PSParser
Write-Host "[2/4] Running basic syntax check..." -NoNewline
try {
    $errors = $null
    $content = Get-Content $ScriptPath -Raw
    $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)

    if ($errors.Count -gt 0) {
        Write-Host " ✗" -ForegroundColor Red
        Write-Host ""
        Write-Host "Syntax Errors Found:" -ForegroundColor Red
        $errors | ForEach-Object {
            Write-Host "  Line $($_.Token.StartLine): $($_.Message)" -ForegroundColor Yellow
        }
        exit 1
    } else {
        Write-Host " ✓" -ForegroundColor Green
    }
} catch {
    Write-Host " ✗" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
}

# Test 3: Advanced syntax check using AST
Write-Host "[3/4] Running advanced syntax check..." -NoNewline
try {
    $scriptBlock = [ScriptBlock]::Create($content)
    Write-Host " ✓" -ForegroundColor Green
} catch {
    Write-Host " ✗" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
}

# Test 4: Check for common issues
Write-Host "[4/4] Checking for common issues..." -NoNewline
$issues = @()

# Check for smart quotes
if ($content -match '[""]') {
    $issues += "Found smart quotes (should use straight quotes)"
}

# Check for tabs vs spaces inconsistency
$lines = Get-Content $ScriptPath
$tabLines = $lines | Where-Object { $_ -match '^\t' }
$spaceLines = $lines | Where-Object { $_ -match '^    ' }
if ($tabLines.Count -gt 0 -and $spaceLines.Count -gt 0) {
    $issues += "Mixed tabs and spaces detected"
}

# Check for BOM
$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $ScriptPath))
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $issues += "UTF-8 BOM detected (usually okay, but can cause issues)"
}

if ($issues.Count -gt 0) {
    Write-Host " ⚠" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Warnings:" -ForegroundColor Yellow
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
} else {
    Write-Host " ✓" -ForegroundColor Green
}

# Summary
Write-Host ""
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "✓ All syntax checks passed!" -ForegroundColor Green
Write-Host ""
Write-Host "The script appears to be valid PowerShell." -ForegroundColor White
Write-Host ""
Write-Host "To run the script:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File `"$ScriptPath`"" -ForegroundColor White
Write-Host ""
Write-Host "Or set execution policy once:" -ForegroundColor Cyan
Write-Host "  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
