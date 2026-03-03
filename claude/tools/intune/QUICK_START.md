# Quick Start Guide - Intune Orro Policy Reporter

Generate Intune configuration reports for policies starting with "Orro" in under 5 minutes!

## Choose Your Tool

### ⚡ PowerShell (Recommended for Windows Users)

**Best if you:**
- Use Windows
- Prefer PowerShell
- Want the quickest setup
- Don't want to install Python

**Quick Start:**
```powershell
cd C:\Users\olli.ojala\maia\claude\tools\intune
.\Run-OrroReport.ps1
```

That's it! The script will guide you through the rest.

[→ Full PowerShell Documentation](README_PowerShell.md)

---

### 🐍 Python (Cross-Platform)

**Best if you:**
- Need cross-platform support
- Already have Python installed
- Prefer Python scripting
- Want to customize the tool

**Quick Start:**
```bash
pip install msal python-docx requests

python intune_policy_reporter.py \
  --tenant-id YOUR_TENANT_ID \
  --client-id YOUR_CLIENT_ID \
  --client-secret YOUR_CLIENT_SECRET
```

[→ Full Python Documentation](README.md)

---

## What You'll Get

Both versions produce the same professional Word document report:

📄 **Intune_Orro_Configuration_Report.docx**
- Executive summary with policy counts
- Detailed configuration for each policy
- Assignment information
- Full settings in readable format

## Authentication Comparison

| Method | PowerShell | Python | Best For |
|--------|-----------|--------|----------|
| **Interactive** | ✅ Supported | ❌ Not available | One-time reports, getting started |
| **App-Only** | ✅ Supported | ✅ Supported | Automation, scheduled reports |
| **Setup Complexity** | Low (browser login) | Medium (Azure AD app) | - |

## Setup Time Comparison

### PowerShell with Interactive Auth
⏱️ **~2 minutes**
1. Run script
2. Sign in with browser
3. Done!

### PowerShell with App-Only Auth
⏱️ **~10 minutes**
1. Create Azure AD app (5 min)
2. Configure permissions (3 min)
3. Run script with credentials (2 min)

### Python
⏱️ **~10 minutes**
1. Install Python packages (2 min)
2. Create Azure AD app (5 min)
3. Configure permissions (3 min)
4. Run script with credentials (2 min)

## Feature Comparison

| Feature | PowerShell | Python |
|---------|-----------|--------|
| **Device Configs** | ✅ | ✅ |
| **Compliance Policies** | ✅ | ✅ |
| **App Protection** | ✅ | ✅ |
| **Config Profiles** | ✅ | ✅ |
| **Word Output** | ✅ (COM) | ✅ (python-docx) |
| **Custom Prefix** | ✅ | ✅ |
| **Auto-install deps** | ✅ | ❌ (manual) |
| **Credential Storage** | ✅ | ✅ (optional) |

## Recommended Workflows

### First-Time User (Want to Try It)
```
Use: PowerShell with Interactive Auth
Command: .\Run-OrroReport.ps1
Time: 2 minutes
```

### Regular Manual Reports
```
Use: PowerShell with Interactive Auth
Command: .\Run-OrroReport.ps1
Time: 1 minute per report
```

### Automated/Scheduled Reports
```
Use: Either PowerShell or Python with App-Only Auth
Setup: Once (10 min)
Running: Fully automated
```

### Multi-Platform Teams
```
Use: Python
Reason: Works on Windows, macOS, Linux
Setup: Once per platform
```

## Common Use Cases

### Use Case 1: "I just want a quick report now"
**Solution:** PowerShell Interactive
```powershell
.\Run-OrroReport.ps1
# Opens browser, sign in, report generated
```

### Use Case 2: "I need weekly automated reports"
**Solution:** PowerShell App-Only + Scheduled Task
```powershell
# Setup once
.\Run-OrroReport.ps1 -SaveCredentials

# Schedule task (runs weekly automatically)
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File `"C:\Users\olli.ojala\maia\claude\tools\intune\Run-OrroReport.ps1`""
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 8am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "Intune Orro Report"
```

### Use Case 3: "I need to customize the output format"
**Solution:** Python (easier to modify)
```python
# Edit intune_policy_reporter.py
# Change reporter.create_report() to export CSV, JSON, etc.
```

### Use Case 4: "I need reports for multiple organizations"
**Solution:** Either, with scripting
```powershell
# PowerShell loop
@("Orro", "Contoso", "Fabrikam") | ForEach-Object {
    .\Get-IntuneOrroReport.ps1 -UseInteractive -Prefix $_ -OutputPath "$($_)_Report.docx"
}
```

## Troubleshooting Quick Fixes

### PowerShell: "Module not found"
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

### Python: "Module not found"
```bash
pip install msal python-docx requests
```

### "No policies found"
- Check policy names start with "Orro"
- Try: `-Prefix "*"` to see all policies
- Verify you have permissions to view Intune

### "Authentication failed"
- PowerShell: Ensure you're a Global Reader or Intune Admin
- Python: Verify client ID/secret are correct
- Both: Check API permissions are granted

## Next Steps

1. **Choose your tool** (PowerShell or Python)
2. **Run your first report** (follow Quick Start above)
3. **Review the output** (Word document)
4. **Automate if needed** (save credentials, schedule)

## Support Files

| File | Purpose |
|------|---------|
| `Get-IntuneOrroReport.ps1` | Main PowerShell script |
| `Run-OrroReport.ps1` | PowerShell launcher/wrapper |
| `intune_policy_reporter.py` | Main Python script |
| `setup_guide.py` | Python setup wizard |
| `README_PowerShell.md` | Full PowerShell docs |
| `README.md` | Full Python docs |
| `QUICK_START.md` | This file |

---

**Still unsure? Start with PowerShell Interactive - it's the fastest way to get your first report!**

```powershell
cd C:\Users\olli.ojala\maia\claude\tools\intune
.\Run-OrroReport.ps1
```
