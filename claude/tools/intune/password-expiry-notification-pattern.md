# Password Expiry Notification System
## Repeatable Pattern for Managed Service Customers

**Document Version:** 1.0
**Last Updated:** 2026-01-07
**Author:** Principal Endpoint Engineer
**Status:** Draft for Engineering Review

---

## Executive Summary

This document describes a standardized, repeatable pattern for deploying Active Directory password expiry notification systems across managed service customers. The solution provides proactive user notifications, reduces helpdesk calls, and includes robust monitoring via Datto RMM.

### Business Value

| Metric | Impact |
|--------|--------|
| Password-related helpdesk tickets | ↓ 40-60% reduction |
| Account lockouts from expired passwords | ↓ 70% reduction |
| User productivity loss | ↓ 2-4 hours per incident avoided |
| Proactive vs reactive support | Shifts support model left |

---

## Solution Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Customer Environment                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────┐     ┌──────────────────┐                      │
│  │  Domain          │     │  Task Scheduler  │                      │
│  │  Controller      │────▶│  (Daily 7am)     │                      │
│  │  (AD Query)      │     │                  │                      │
│  └──────────────────┘     └────────┬─────────┘                      │
│                                    │                                 │
│                                    ▼                                 │
│                     ┌──────────────────────────┐                    │
│                     │  Password Expiry Script  │                    │
│                     │  - Query AD users        │                    │
│                     │  - Calculate expiry      │                    │
│                     │  - Send notifications    │                    │
│                     │  - Write heartbeat       │                    │
│                     └────────────┬─────────────┘                    │
│                                  │                                   │
│                    ┌─────────────┴─────────────┐                    │
│                    ▼                           ▼                     │
│     ┌──────────────────────┐    ┌──────────────────────┐           │
│     │  SMTP Server         │    │  Heartbeat File      │           │
│     │  (Email delivery)    │    │  (JSON status)       │           │
│     └──────────────────────┘    └──────────┬───────────┘           │
│                                             │                        │
└─────────────────────────────────────────────┼────────────────────────┘
                                              │
                                              ▼
                              ┌───────────────────────────┐
                              │  Datto RMM                │
                              │  - Heartbeat monitor      │
                              │  - Alert on failure only  │
                              │  - 4-hour check interval  │
                              └───────────────────────────┘
```

### Notification Flow

```
Day 30 ──▶ Email: "Your password expires in 30 days"
Day 15 ──▶ Email: "Your password expires in 15 days"
Day 5  ──▶ Email: "Your password expires in 5 days"
Day 3  ──▶ Email: "Your password expires in 3 days" (HIGH PRIORITY)
Day 1  ──▶ Email: "Your password expires in 1 day" (HIGH PRIORITY)
Day 0  ──▶ Password expired - user cannot log in
```

---

## Technical Specifications

### Prerequisites

| Requirement | Details |
|-------------|---------|
| Server OS | Windows Server 2016+ |
| PowerShell | Version 5.1+ |
| AD Module | `RSAT-AD-PowerShell` feature installed |
| Permissions | Service account with AD read access |
| SMTP | Relay server accessible from script host |
| Datto RMM | Agent installed on script host |

### File Locations (Standardized)

| File | Path | Purpose |
|------|------|---------|
| Main Script | `C:\Scripts\PasswordExpiryReminder.ps1` | Core notification logic |
| Log Files | `C:\Scripts\Log\expiry-{timestamp}.txt` | Execution transcripts |
| Heartbeat | `C:\Scripts\Heartbeat\PasswordReminder.json` | Monitoring status file |

---

## Deployment Guide

### Phase 1: Environment Assessment

**Checklist:**

- [ ] Identify SMTP relay server and test connectivity
- [ ] Confirm AD module available on target server
- [ ] Identify service account for script execution
- [ ] Determine customer branding requirements (logo, colors, contact info)
- [ ] Confirm Datto RMM agent installed and reporting
- [ ] Document customer-specific reminder schedule (if different from default)

### Phase 2: Script Customization

**Required Customizations per Customer:**

```powershell
# Customer-specific variables (lines 3-8 of script)
$reminderdays = @(30, 15, 5, 3, 1)           # Adjust reminder schedule
$priorityreminder = 3                         # Days before high-priority
$from = "IT Support <noreply@customer.com>"   # Customer sender address
$smtp = "smtp.customer.com"                   # Customer SMTP relay
$companyName = "Customer Name"                # For email template
$supportEmail = "support@customer.com"        # Helpdesk contact
$supportPhone = "(03) 9999 9999"              # Helpdesk phone
```

**Email Template Customization:**

- Replace logo URL with customer branding
- Update support contact information
- Adjust password change instructions URL
- Modify color scheme to match customer brand

### Phase 3: Deployment Steps

#### 3.1 Create Folder Structure

```powershell
# Run on target server
New-Item -Path "C:\Scripts" -ItemType Directory -Force
New-Item -Path "C:\Scripts\Log" -ItemType Directory -Force
New-Item -Path "C:\Scripts\Heartbeat" -ItemType Directory -Force
```

#### 3.2 Deploy Script

1. Copy customized `PasswordExpiryReminder.ps1` to `C:\Scripts\`
2. Set appropriate file permissions (restrict to service account + admins)

#### 3.3 Create Scheduled Task

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File C:\Scripts\PasswordExpiryReminder.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At "7:00AM"

$principal = New-ScheduledTaskPrincipal -UserId "DOMAIN\svc_pwdreminder" `
    -LogonType Password -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName "Password Expiry Reminder" `
    -Action $action -Trigger $trigger -Principal $principal -Settings $settings `
    -Description "Sends password expiry notifications to AD users"
```

#### 3.4 Test Execution

```powershell
# Manual test run
& "C:\Scripts\PasswordExpiryReminder.ps1"

# Verify outputs
Get-Content "C:\Scripts\Heartbeat\PasswordReminder.json"
Get-ChildItem "C:\Scripts\Log\expiry-*.txt" | Select-Object -Last 1 | Get-Content
```

### Phase 4: Datto RMM Monitoring Setup

#### 4.1 Deploy Heartbeat Monitor Component

**Component Name:** `Monitor - Password Reminder Heartbeat`
**Category:** `Monitoring`
**Script Type:** `PowerShell`

```powershell
# Monitor-PasswordReminderHeartbeat.ps1
param(
    [int]$MaxAgeHours = 25,
    [string]$HeartbeatPath = "C:\Scripts\Heartbeat\PasswordReminder.json"
)

try {
    # Check if heartbeat file exists
    if (-not (Test-Path $HeartbeatPath)) {
        Write-Host "ALERT: Heartbeat file not found at $HeartbeatPath"
        Write-Host "Password Reminder script may never have run on this server."
        exit 1
    }

    # Read heartbeat data
    $heartbeat = Get-Content $HeartbeatPath -Raw | ConvertFrom-Json

    # Check status
    if ($heartbeat.Status -eq "Failed") {
        Write-Host "ALERT: Password Reminder script last run failed"
        Write-Host "Last Run: $($heartbeat.LastRun)"
        Write-Host "Error: $($heartbeat.Error)"
        exit 1
    }

    # Check age
    $lastRun = [DateTime]::Parse($heartbeat.LastRun)
    $age = (Get-Date) - $lastRun

    if ($age.TotalHours -gt $MaxAgeHours) {
        Write-Host "ALERT: Heartbeat file is stale"
        Write-Host "Last Run: $($heartbeat.LastRun) ($([math]::Round($age.TotalHours, 1)) hours ago)"
        Write-Host "Threshold: $MaxAgeHours hours"
        exit 1
    }

    # All checks passed
    Write-Host "OK: Password Reminder script is healthy"
    Write-Host "Last Run: $($heartbeat.LastRun)"
    Write-Host "Users Processed: $($heartbeat.UsersProcessed)"
    Write-Host "Age: $([math]::Round($age.TotalHours, 1)) hours"
    exit 0
}
catch {
    Write-Host "ALERT: Error reading heartbeat file"
    Write-Host "Error: $($_.Exception.Message)"
    exit 1
}
```

#### 4.2 Create Scheduled Job

| Setting | Value |
|---------|-------|
| Name | `Password Reminder Health Check` |
| Component | `Monitor - Password Reminder Heartbeat` |
| Target | Server running password script |
| Schedule | Every 4 hours |
| Alert on Failure | ✅ Enabled |
| Alert Priority | High |

#### 4.3 Configure Alert Notification

In Datto RMM **Setup → Alerts**:

- **Filter:** Component Name contains `Password Reminder Heartbeat` AND Exit Code = 1
- **Action:** Email to MSP alerts distribution list
- **Auto-resolve:** When exit code returns to 0

---

## Reference Implementation

### Complete Password Expiry Script (Template)

```powershell
<#
.SYNOPSIS
    Active Directory Password Expiry Notification Script

.DESCRIPTION
    Queries AD for users with expiring passwords and sends email notifications
    at configurable intervals. Writes heartbeat file for external monitoring.

.NOTES
    Version:        2.0
    Template For:   MSP Customer Deployment
    Requires:       ActiveDirectory PowerShell module
                    SMTP relay access
                    AD read permissions
#>

#region Configuration
# ============================================================================
# CUSTOMER-SPECIFIC SETTINGS - Modify these for each deployment
# ============================================================================

$reminderDays = @(30, 15, 5, 3, 1)              # Days before expiry to remind
$priorityThreshold = 3                           # Days before sending high priority
$from = "IT Support <noreply@customer.com>"      # Sender email address
$smtp = "smtp.customer.com"                      # SMTP relay server
$companyName = "Customer Name"                   # Company name for emails
$supportEmail = "support@customer.com"           # Helpdesk email
$supportPhone = "(03) 9999 9999"                 # Helpdesk phone
$passwordChangeUrl = "https://aka.ms/sspr"       # Password reset URL

# File paths (standardized)
$scriptRoot = "C:\Scripts"
$logFolder = "$scriptRoot\Log"
$heartbeatPath = "$scriptRoot\Heartbeat\PasswordReminder.json"

#endregion

#region Email Template
# ============================================================================
# HTML Email Template - Customize branding as needed
# ============================================================================

$emailTemplate = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: 'Segoe UI', Arial, sans-serif; }}
        .container {{ max-width: 600px; margin: auto; }}
        .header {{ background-color: #0078D4; padding: 20px; text-align: center; }}
        .header img {{ max-width: 200px; }}
        .content {{ padding: 30px; background-color: #ffffff; border: 1px solid #e0e0e0; }}
        .alert {{ background-color: #FFF4CE; border-left: 4px solid #FFB900; padding: 15px; margin: 20px 0; }}
        .footer {{ padding: 20px; background-color: #f5f5f5; font-size: 12px; color: #666; }}
        .button {{ background-color: #0078D4; color: white; padding: 12px 24px; text-decoration: none; display: inline-block; margin: 20px 0; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1 style="color: white; margin: 0;">$companyName</h1>
        </div>
        <div class="content">
            <h2>Password Expiry Notice</h2>

            <p>Hi {0},</p>

            <div class="alert">
                <strong>Your network password will expire in {1} days.</strong>
            </div>

            <p>To avoid any interruption to your work, please change your password before it expires.</p>

            <a href="$passwordChangeUrl" class="button">Change Password Now</a>

            <h3>Need Help?</h3>
            <p>If you experience any difficulties, please contact the IT Helpdesk:</p>
            <ul>
                <li>Email: <a href="mailto:$supportEmail">$supportEmail</a></li>
                <li>Phone: $supportPhone</li>
            </ul>
        </div>
        <div class="footer">
            <p>This is an automated message from the $companyName IT Department.</p>
        </div>
    </div>
</body>
</html>
"@

#endregion

#region Functions
# ============================================================================
# Helper Functions
# ============================================================================

function Write-Heartbeat {
    param(
        [string]$Status,
        [int]$UsersProcessed = 0,
        [string]$Error = ""
    )

    $heartbeat = @{
        LastRun        = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Status         = $Status
        UsersProcessed = $UsersProcessed
        ServerName     = $env:COMPUTERNAME
        Error          = $Error
    }

    # Ensure directory exists
    $heartbeatDir = Split-Path $heartbeatPath -Parent
    if (-not (Test-Path $heartbeatDir)) {
        New-Item -Path $heartbeatDir -ItemType Directory -Force | Out-Null
    }

    $heartbeat | ConvertTo-Json | Out-File $heartbeatPath -Force
}

function Send-ExpiryNotification {
    param(
        [string]$To,
        [string]$Name,
        [int]$DaysToExpire
    )

    $subject = "Password Expiry Notice - Your password expires in $DaysToExpire days"
    $body = $emailTemplate -f $Name, $DaysToExpire

    $mailParams = @{
        To          = $To
        From        = $from
        Subject     = $subject
        Body        = $body
        BodyAsHtml  = $true
        SmtpServer  = $smtp
        ErrorAction = "Stop"
    }

    if ($DaysToExpire -le $priorityThreshold) {
        $mailParams.Priority = "High"
    }

    Send-MailMessage @mailParams
}

#endregion

#region Main Execution
# ============================================================================
# Main Script Logic
# ============================================================================

$timeStamp = Get-Date -Format "yyyyMMdd-HHmm"
$transcriptFile = "$logFolder\expiry-$timeStamp.txt"

# Ensure log directory exists
if (-not (Test-Path $logFolder)) {
    New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
}

Start-Transcript $transcriptFile

try {
    # Import AD module
    if (-not (Get-Module ActiveDirectory)) {
        Import-Module ActiveDirectory -ErrorAction Stop
    }

    # Query users with expiring passwords
    $users = Get-ADUser -Filter {
        (Enabled -eq $true) -and
        (PasswordNeverExpires -eq $false) -and
        (PasswordExpired -eq $false)
    } -Properties Name, PasswordLastSet, EmailAddress, PasswordNeverExpires

    Write-Host "Found $($users.Count) users with password expiry enabled"

    # Get default password policy
    $defaultMaxAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge

    $notificationsSent = 0

    foreach ($user in $users) {
        $name = $user.Name
        $email = $user.EmailAddress
        $passwordLastSet = $user.PasswordLastSet

        # Skip if no email
        if ([string]::IsNullOrEmpty($email)) {
            Write-Host "  Skipping $name - no email address"
            continue
        }

        # Check for Fine-Grained Password Policy
        $fgpp = Get-ADUserResultantPasswordPolicy -Identity $user -ErrorAction SilentlyContinue
        $maxAge = if ($fgpp) { $fgpp.MaxPasswordAge } else { $defaultMaxAge }

        # Calculate days to expiry
        $expiryDate = $passwordLastSet + $maxAge
        $daysToExpire = (New-TimeSpan -Start (Get-Date) -End $expiryDate).Days

        Write-Host "  $name - Password expires in $daysToExpire days"

        # Check if we should send notification
        if ($reminderDays -contains $daysToExpire) {
            try {
                Send-ExpiryNotification -To $email -Name $name -DaysToExpire $daysToExpire
                Write-Host "    ✓ Notification sent to $email"
                $notificationsSent++
            }
            catch {
                Write-Host "    ✗ Failed to send notification: $($_.Exception.Message)"
            }
        }
    }

    Write-Host "`nCompleted: $notificationsSent notifications sent"

    # Write success heartbeat
    Write-Heartbeat -Status "Success" -UsersProcessed $users.Count
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"

    # Write failure heartbeat
    Write-Heartbeat -Status "Failed" -Error $_.Exception.Message

    throw
}
finally {
    Stop-Transcript
}

#endregion

# Clean up old log files (keep last 30 days)
Get-ChildItem "$logFolder\expiry-*.txt" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
    Remove-Item -Force
```

---

## Operational Procedures

### Troubleshooting Guide

| Symptom | Likely Cause | Resolution |
|---------|--------------|------------|
| No emails sent | SMTP relay blocked | Test SMTP connectivity: `Test-NetConnection $smtp -Port 25` |
| Heartbeat stale | Scheduled task not running | Check Task Scheduler history, verify service account |
| Users not receiving emails | No email address in AD | Populate EmailAddress attribute in AD |
| Wrong expiry calculation | Fine-Grained Password Policy | Script handles FGPP automatically, verify policy applies |
| High-priority not triggering | Threshold misconfigured | Check `$priorityThreshold` value |

### Log File Review

```powershell
# View latest execution log
Get-ChildItem "C:\Scripts\Log\expiry-*.txt" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 |
    Get-Content

# Check heartbeat status
Get-Content "C:\Scripts\Heartbeat\PasswordReminder.json" | ConvertFrom-Json
```

### Manual Execution

```powershell
# Run script manually for testing
& "C:\Scripts\PasswordExpiryReminder.ps1"

# Test single user notification (modify script temporarily)
Send-ExpiryNotification -To "test@customer.com" -Name "Test User" -DaysToExpire 5
```

---

## Rollout Checklist

### Pre-Deployment

- [ ] Customer approval obtained
- [ ] SMTP relay server documented and tested
- [ ] Service account created with AD read permissions
- [ ] Branding assets collected (logo URL, colors, contact info)
- [ ] Reminder schedule confirmed with customer

### Deployment

- [ ] Folder structure created on target server
- [ ] Script customized and deployed
- [ ] Scheduled task created and tested
- [ ] Manual execution successful
- [ ] Heartbeat file generated correctly

### Monitoring Setup

- [ ] Datto RMM component deployed
- [ ] Scheduled job created (4-hour interval)
- [ ] Alert notification configured
- [ ] Test alert triggered and received

### Post-Deployment

- [ ] Documentation updated in customer portal
- [ ] Customer IT team notified
- [ ] Handover notes completed
- [ ] First week monitoring confirmed

---

## Appendix

### A. Security Considerations

| Concern | Mitigation |
|---------|------------|
| Service account permissions | Read-only AD access, no write permissions |
| Email spoofing | Configure SPF/DKIM for sender domain |
| Script tampering | Restrict file permissions, integrity monitoring |
| Credential storage | Use managed service account or gMSA |

### B. Customization Options

| Feature | Configuration |
|---------|---------------|
| Reminder schedule | Modify `$reminderDays` array |
| High-priority threshold | Modify `$priorityThreshold` |
| Email template | Replace HTML in `$emailTemplate` |
| Log retention | Modify cleanup period (default 30 days) |
| Heartbeat check interval | Modify Datto job schedule |

### C. Related Documentation

- Microsoft Docs: [Get-ADUser](https://docs.microsoft.com/en-us/powershell/module/activedirectory/get-aduser)
- Microsoft Docs: [Fine-Grained Password Policies](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/adac/introduction-to-active-directory-administrative-center-enhancements--level-100-#fine_grained_pswd_policy_mgmt)
- Datto RMM: [Creating Components](https://rmm.datto.com/help/en/Content/4WEBPORTAL/Components/Components.htm)

---

## Document Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-07 | Principal Endpoint Engineer | Initial draft |

---

**Document Status:** Ready for Engineering Review
**Next Steps:** Team discussion, pilot customer selection, feedback incorporation
