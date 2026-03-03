<#
.SYNOPSIS
    Adds the Entra ID Connect VM Infrastructure section to the Solution Design document
.DESCRIPTION
    Opens the Word document and appends the new section 7.3 at the end.
    Review placement and move to appropriate location after Section 7.2.
.NOTES
    Run this script, then manually position the section in Word if needed.
#>

$docPath = "C:\Users\olli.ojala\maia\data\Word\NWR-Microsoft Intune + Windows Device Management – Solution Design v1.4.docx"

# Try with en-dash first, then regular hyphen
if (-not (Test-Path $docPath)) {
    $docPath = "C:\Users\olli.ojala\maia\data\Word\NWR-Microsoft Intune + Windows Device Management - Solution Design v1.4.docx"
}

$word = New-Object -ComObject Word.Application
$word.Visible = $true

try {
    $doc = $word.Documents.Open($docPath)

    # Move to end of document
    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)

    # Add page break before new section
    $range.InsertBreak([Microsoft.Office.Interop.Word.WdBreakType]::wdPageBreak)

    # Add heading
    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.Text = "7.3 Entra ID Connect Virtual Machine Infrastructure`r`n"
    $range.Style = "Heading 2"

    # Add Overview section
    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()
    $range.Text = "Overview`r`n"
    $range.Style = "Heading 3"

    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()
    $range.Text = "Two new virtual machines are required to support the Entra ID Connect (Azure AD Connect) deployment for MDM Intune configuration management. These servers will synchronize the on-premises Active Directory with Microsoft Entra ID, enabling hybrid identity for device management.`r`n"

    # VM Specifications heading
    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()
    $range.Text = "VM Specifications`r`n"
    $range.Style = "Heading 3"

    # Create VM Specifications table
    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()

    $table1 = $doc.Tables.Add($range, 5, 2)
    $table1.Borders.Enable = $true
    $table1.Cell(1,1).Range.Text = "Specification"
    $table1.Cell(1,2).Range.Text = "Requirement"
    $table1.Cell(2,1).Range.Text = "Operating System"
    $table1.Cell(2,2).Range.Text = "Windows Server 2022 Standard (or higher edition)"
    $table1.Cell(3,1).Range.Text = "CPU"
    $table1.Cell(3,2).Range.Text = "Dual core, 1.6 GHz minimum"
    $table1.Cell(4,1).Range.Text = "Memory"
    $table1.Cell(4,2).Range.Text = "6 GB RAM"
    $table1.Cell(5,1).Range.Text = "Storage"
    $table1.Cell(5,2).Range.Text = "70 GB SSD"
    $table1.Rows.Item(1).Range.Bold = $true

    # Software Requirements heading
    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()
    $range.InsertParagraphAfter()
    $range.Text = "Software & Framework Requirements`r`n"
    $range.Style = "Heading 3"

    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()

    $table2 = $doc.Tables.Add($range, 5, 2)
    $table2.Borders.Enable = $true
    $table2.Cell(1,1).Range.Text = "Component"
    $table2.Cell(1,2).Range.Text = "Requirement"
    $table2.Cell(2,1).Range.Text = "PowerShell"
    $table2.Cell(2,2).Range.Text = "Version 5.0 or later"
    $table2.Cell(3,1).Range.Text = ".NET Framework"
    $table2.Cell(3,2).Range.Text = "Version 4.8 or later"
    $table2.Cell(4,1).Range.Text = "Execution Policy"
    $table2.Cell(4,2).Range.Text = "RemoteSigned (recommended during installation)"
    $table2.Cell(5,1).Range.Text = "TLS"
    $table2.Cell(5,2).Range.Text = "TLS 1.2 must be enabled"
    $table2.Rows.Item(1).Range.Bold = $true

    # Security & Endpoint Protection
    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()
    $range.InsertParagraphAfter()
    $range.Text = "Security & Endpoint Protection`r`n"
    $range.Style = "Heading 3"

    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()

    $table3 = $doc.Tables.Add($range, 3, 2)
    $table3.Borders.Enable = $true
    $table3.Cell(1,1).Range.Text = "Agent"
    $table3.Cell(1,2).Range.Text = "Requirement"
    $table3.Cell(2,1).Range.Text = "Rapid7"
    $table3.Cell(2,2).Range.Text = "Must be installed"
    $table3.Cell(3,1).Range.Text = "SentinelOne (S1)"
    $table3.Cell(3,2).Range.Text = "Must be installed"
    $table3.Rows.Item(1).Range.Bold = $true

    # Domain & Network Requirements
    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()
    $range.InsertParagraphAfter()
    $range.Text = "Domain & Network Requirements`r`n"
    $range.Style = "Heading 3"

    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()

    $table4 = $doc.Tables.Add($range, 7, 2)
    $table4.Borders.Enable = $true
    $table4.Cell(1,1).Range.Text = "Requirement"
    $table4.Cell(1,2).Range.Text = "Details"
    $table4.Cell(2,1).Range.Text = "Domain Join"
    $table4.Cell(2,2).Range.Text = "Servers must be domain joined to on-premises Active Directory"
    $table4.Cell(3,1).Range.Text = "Server Type"
    $table4.Cell(3,2).Range.Text = "GUI installation required (Windows Server Core is NOT supported)"
    $table4.Cell(4,1).Range.Text = "AD Connectivity"
    $table4.Cell(4,2).Range.Text = "Entra ID Connect uses LDAPS to connect to Active Directory (by default, uses LDAP connections that are signed and encrypted)"
    $table4.Cell(5,1).Range.Text = "Network Zone"
    $table4.Cell(5,2).Range.Text = "Tier 0 asset - should be placed in the same zone as Domain Controllers"
    $table4.Cell(6,1).Range.Text = "Firewall"
    $table4.Cell(6,2).Range.Text = "Zones managed via Palo Alto firewall"
    $table4.Cell(7,1).Range.Text = "IP Addressing"
    $table4.Cell(7,2).Range.Text = "IP address allocations to be provided by SICE"
    $table4.Rows.Item(1).Range.Bold = $true

    # VM Naming Convention
    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()
    $range.InsertParagraphAfter()
    $range.Text = "VM Naming Convention`r`n"
    $range.Style = "Heading 3"

    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()

    $table5 = $doc.Tables.Add($range, 3, 2)
    $table5.Borders.Enable = $true
    $table5.Cell(1,1).Range.Text = "Site"
    $table5.Cell(1,2).Range.Text = "VM Name"
    $table5.Cell(2,1).Range.Text = "M7EC"
    $table5.Cell(2,2).Range.Text = "M7EC-EC1-CYB-01"
    $table5.Cell(3,1).Range.Text = "PH"
    $table5.Cell(3,2).Range.Text = "PH-EC2-CYB-01"
    $table5.Rows.Item(1).Range.Bold = $true

    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()
    $range.Text = "Note: Final naming to be confirmed by NWR as these are customer-owned assets.`r`n"
    $range.Italic = $true

    # Backup Requirements
    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()
    $range.Text = "Backup Requirements`r`n"
    $range.Style = "Heading 3"

    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()
    $range.Text = "Servers must be included in the backup schedule.`r`n"

    # Security Classification
    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()
    $range.Text = "Security Classification`r`n"
    $range.Style = "Heading 3"

    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()
    $range.Text = "These VMs are classified as Tier 0 assets, equivalent to Domain Controllers, due to their role in identity synchronization. They require:`r`n"

    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()
    $range.Text = "`t• Placement in the same network zone as Domain Controllers`r`n`t• Equivalent security controls and monitoring`r`n`t• Restricted administrative access following least privilege principles`r`n`t• Continuous monitoring and logging`r`n"

    # Approval Status
    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()
    $range.Text = "Approval Status`r`n"
    $range.Style = "Heading 3"

    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()

    $table6 = $doc.Tables.Add($range, 3, 4)
    $table6.Borders.Enable = $true
    $table6.Cell(1,1).Range.Text = "Approval Type"
    $table6.Cell(1,2).Range.Text = "Status"
    $table6.Cell(1,3).Range.Text = "Approver"
    $table6.Cell(1,4).Range.Text = "Date"
    $table6.Cell(2,1).Range.Text = "Cyber Security Approval"
    $table6.Cell(2,2).Range.Text = "Approved with conditions"
    $table6.Cell(2,3).Range.Text = "Avi Lipa"
    $table6.Cell(2,4).Range.Text = "04/Nov/25"
    $table6.Cell(3,1).Range.Text = "Configuration Confirmation"
    $table6.Cell(3,2).Range.Text = "Confirmed"
    $table6.Cell(3,3).Range.Text = "ORRO"
    $table6.Cell(3,4).Range.Text = "10/Nov/25"
    $table6.Rows.Item(1).Range.Bold = $true

    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()
    $range.InsertParagraphAfter()
    $range.Text = "Cyber Security Conditions:`r`n`t• R7 and S1 agents must be installed`r`n`t• ORRO to provide hardening guidance and confirm if SICE GPOs can be used or if ORRO will supply their own hardening configuration`r`n"

    # Action Items
    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()
    $range.Text = "Action Items`r`n"
    $range.Style = "Heading 3"

    $range = $doc.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $range.InsertParagraphAfter()

    $table7 = $doc.Tables.Add($range, 6, 3)
    $table7.Borders.Enable = $true
    $table7.Cell(1,1).Range.Text = "Action"
    $table7.Cell(1,2).Range.Text = "Responsible Party"
    $table7.Cell(1,3).Range.Text = "Status"
    $table7.Cell(2,1).Range.Text = "Provide IP address allocations"
    $table7.Cell(2,2).Range.Text = "SICE"
    $table7.Cell(2,3).Range.Text = "Pending"
    $table7.Cell(3,1).Range.Text = "Confirm network zone configuration (Palo Alto)"
    $table7.Cell(3,2).Range.Text = "SICE"
    $table7.Cell(3,3).Range.Text = "Pending"
    $table7.Cell(4,1).Range.Text = "Confirm hardening requirements/GPOs"
    $table7.Cell(4,2).Range.Text = "ORRO"
    $table7.Cell(4,3).Range.Text = "Pending"
    $table7.Cell(5,1).Range.Text = "Configure backup schedule"
    $table7.Cell(5,2).Range.Text = "SICE"
    $table7.Cell(5,3).Range.Text = "Pending"
    $table7.Cell(6,1).Range.Text = "Install R7 and S1 agents"
    $table7.Cell(6,2).Range.Text = "SICE"
    $table7.Cell(6,3).Range.Text = "Pending"
    $table7.Rows.Item(1).Range.Bold = $true

    # Save the document
    $doc.Save()

    Write-Host "Section 7.3 'Entra ID Connect Virtual Machine Infrastructure' has been added to the document." -ForegroundColor Green
    Write-Host "The section was added at the end of the document." -ForegroundColor Yellow
    Write-Host "Please manually move it to the correct location after Section 7.2 if needed." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Document saved successfully." -ForegroundColor Green

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # Leave Word open for review
    # $word.Quit()
}
