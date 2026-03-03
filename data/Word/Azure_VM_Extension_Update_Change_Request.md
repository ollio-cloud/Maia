# Change Request: MMA to AMA Migration - Sentinel & Monitoring

## Change Details

| Field | Value |
|-------|-------|
| Change ID | CR-XXXX |
| Change Title | Microsoft Monitoring Agent (MMA) to Azure Monitor Agent (AMA) Migration |
| Requested By | Olli Ojala |
| Date Submitted | [Date] |
| Target Implementation Date | [Date - recommend phased rollout] |
| Change Type | **Major** *(Reclassified from Standard - see note below)* |
| Priority | High |
| Risk Level | Medium-High |
| CAB Review Required | Yes |

> **⚠️ Change Type Reclassification Note**: This change was reclassified from "Standard" to "Major" by CAB review because:
> - Affects all customer VMs (enterprise-wide scope)
> - Impacts security monitoring (Sentinel/SIEM) - compliance-critical
> - 4-5 week phased implementation window
> - Complex rollback after Phase 4 (MMA removal)
> - Requires IT Director + full CAB approval per risk matrix

---

## 1. Change Description

Migrate all customer VMs from the deprecated Microsoft Monitoring Agent (MMA) to Azure Monitor Agent (AMA) for Sentinel and Log Analytics data collection.

### Business Justification

- **MMA Deprecation**: Microsoft deprecated MMA in August 2024 - continued use risks loss of support and functionality
- **Security Compliance**: Sentinel (SIEM) relies on this agent for security event collection
- **Future-Proofing**: AMA is the strategic platform for all Azure monitoring going forward
- **Enhanced Capabilities**: AMA offers improved performance, security (managed identity), and flexible data collection rules

### Current Legacy Solutions (mips-sentinel-log-analytics workspace)

| Solution | Purpose | AMA Compatibility |
|----------|---------|-------------------|
| **SecurityInsights** | Microsoft Sentinel (SIEM) | ✅ Fully supported via DCR |
| **LogicAppsManagement** | SOAR automation playbooks | ✅ No agent dependency (API-based) |
| **NetworkMonitoring** | Network Performance Monitor | ⚠️ Requires Connection Monitor migration |
| **SecurityCenterFree** | Defender for Cloud (free tier) | ✅ Supported via Defender plans + AMA |

### Scope

- Migrate all customer VMs from MMA to AMA
- Create Data Collection Rules (DCRs) for each data type
- Validate Sentinel alerts and queries post-migration
- Remove MMA after successful AMA validation
- Address Network Monitoring migration separately if required

---

## 2. Technical Architecture

### 2.1 MMA vs AMA Comparison

| Aspect | MMA (Current - Deprecated) | AMA (Target) |
|--------|----------------------------|--------------|
| Authentication | Workspace ID + Shared Key | Managed Identity (recommended) or Service Principal |
| Configuration | Agent-side workspace config | Centralized Data Collection Rules (DCR) |
| Data Routing | Single workspace (complex multi-homing) | Native multi-destination support |
| Security Events | SecurityEvent table | SecurityEvent table (same schema) |
| Syslog (Linux) | Syslog table | Syslog table (same schema) |
| Performance | Perf table | Perf table (same schema) |
| Custom Logs | Custom log definitions | DCR transformations |
| Management | Per-VM configuration | Centralized DCR + DCRA assignments |

### 2.2 Data Collection Rules Required

| DCR Name | Data Types | Target Table | Priority |
|----------|------------|--------------|----------|
| dcr-sentinel-security-events | Windows Security Events | SecurityEvent | Critical |
| dcr-sentinel-syslog | Linux Syslog | Syslog | Critical |
| dcr-performance-counters | CPU, Memory, Disk, Network | Perf | High |
| dcr-windows-events | Application, System logs | Event | Medium |

### 2.3 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     CURRENT STATE (MMA)                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐    Workspace Key     ┌──────────────────────┐    │
│  │ VM + MMA │ ──────────────────── │ mips-sentinel-log-   │    │
│  │          │    Direct Connect    │ analytics            │    │
│  └──────────┘                      │                      │    │
│                                    │ • SecurityInsights   │    │
│  ┌──────────┐                      │ • LogicAppsManagement│    │
│  │ VM + MMA │ ──────────────────── │ • NetworkMonitoring  │    │
│  └──────────┘                      │ • SecurityCenterFree │    │
│                                    └──────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     TARGET STATE (AMA)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐                      ┌──────────────────────┐    │
│  │ VM + AMA │ ─┐  Managed Identity │ mips-sentinel-log-   │    │
│  │          │  │                   │ analytics            │    │
│  └──────────┘  │  ┌─────────────┐  │                      │    │
│                ├──│ DCR         │──│ • SecurityInsights   │    │
│  ┌──────────┐  │  │ (Centralized│  │ • LogicAppsManagement│    │
│  │ VM + AMA │ ─┘  │  Rules)     │  │ • SecurityCenterFree │    │
│  └──────────┘     └─────────────┘  └──────────────────────┘    │
│                                                                 │
│  Note: NetworkMonitoring requires separate Connection Monitor   │
│        migration - not dependent on AMA                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Affected Systems

| System | Count | Impact During Migration |
|--------|-------|-------------------------|
| Customer Windows VMs | [Count] | AMA installation (no reboot required) |
| Customer Linux VMs | [Count] | AMA installation (no reboot required) |
| Sentinel Workspace | 1 | No downtime - parallel ingestion |
| Sentinel Analytics Rules | [Count] | Validation required post-migration |
| Logic Apps Playbooks | [Count] | No impact (API-based) |
| Defender for Cloud | All VMs | Re-association with AMA |

---

## 4. Implementation Plan

### 4.1 Phase 0: Pre-Migration Preparation (Week 1)

| Step | Action | Owner | Duration |
|------|--------|-------|----------|
| 1 | Inventory all VMs with MMA agent installed | | 2 hours |
| 2 | Document current MMA workspace configuration | | 1 hour |
| 3 | Audit Sentinel analytics rules for table dependencies | | 2 hours |
| 4 | **Enable system-assigned managed identity on all VMs** | | 2 hours |
| 5 | **Configure RBAC: Assign Monitoring Metrics Publisher role to VMs** | | 2 hours |
| 6 | **Validate network connectivity to AMA endpoints** | | 1 hour |
| 7 | **Store workspace key securely in Key Vault for rollback** | | 30 min |
| 8 | Create DCRs in Azure Portal or via IaC | | 4 hours |
| 9 | Test DCRs on 1-2 pilot VMs | | 4 hours |
| 10 | Validate pilot VM data appears in Sentinel | | 2 hours |
| 11 | Document rollback procedures | | 1 hour |
| 12 | Schedule maintenance windows per customer | | 2 hours |

**VM Inventory Command:**
```bash
# List all VMs with MMA extension
az vm extension list --query "[?name=='MicrosoftMonitoringAgent' || name=='OmsAgentForLinux']" \
  --output table --subscription "<subscription-id>"

# Or via Log Analytics
az monitor log-analytics workspace show --resource-group "<rg>" --workspace-name "mips-sentinel-log-analytics" \
  --query "customerId" -o tsv
```

**Heartbeat Query (identify connected VMs):**
```kusto
Heartbeat
| where TimeGenerated > ago(24h)
| summarize LastHeartbeat = max(TimeGenerated) by Computer, OSType, Version, Category
| order by Computer asc
```

**Enable Managed Identity on VMs (REQUIRED for AMA):**
```bash
# Enable system-assigned managed identity on each VM
az vm identity assign --resource-group "<rg>" --name "<vm-name>"

# Bulk enable for all VMs in resource group
for VM in $(az vm list -g "<rg>" --query "[].name" -o tsv); do
  echo "Enabling managed identity on $VM..."
  az vm identity assign -g "<rg>" -n "$VM"
done
```

**Assign RBAC Role for AMA Data Collection:**
```bash
# Get VM's managed identity principal ID
PRINCIPAL_ID=$(az vm show -g "<rg>" -n "<vm-name>" --query "identity.principalId" -o tsv)

# Assign Monitoring Metrics Publisher role to DCR
az role assignment create \
  --assignee "$PRINCIPAL_ID" \
  --role "Monitoring Metrics Publisher" \
  --scope "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Insights/dataCollectionRules/dcr-sentinel-security-events"

# Repeat for each DCR (security, syslog, performance)
```

**Validate Network Connectivity to AMA Endpoints:**
```bash
# Required endpoints for AMA (verify NSG/firewall allows outbound HTTPS)
# - *.ods.opinsights.azure.com (port 443) - Data ingestion
# - *.oms.opinsights.azure.com (port 443) - OMS gateway
# - *.azure-automation.net (port 443) - Automation
# - *.monitoring.azure.com (port 443) - Metrics ingestion

# Test connectivity from VM (run inside VM)
Test-NetConnection -ComputerName "<workspace-id>.ods.opinsights.azure.com" -Port 443
Test-NetConnection -ComputerName "global.handler.control.monitor.azure.com" -Port 443
```

**Store Workspace Key Securely for Rollback:**
```bash
# Retrieve and store workspace key in Key Vault (required for MMA reinstall if rollback needed)
WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
  -g "<rg>" -n "mips-sentinel-log-analytics" \
  --query "primarySharedKey" -o tsv)

az keyvault secret set \
  --vault-name "<keyvault-name>" \
  --name "mma-workspace-key-backup" \
  --value "$WORKSPACE_KEY"
```

### 4.2 Phase 1: Create Data Collection Rules (Week 1-2)

#### Step 1: Enable Sentinel AMA-Based Data Connectors

> **IMPORTANT**: Before creating DCRs, enable the AMA-based connectors in Sentinel to ensure proper integration.

**Via Azure Portal:**
1. Navigate to **Microsoft Sentinel** → **Data Connectors**
2. Search for "**Windows Security Events via AMA**" → Click **Open connector page** → **Create data collection rule**
3. Search for "**Syslog via AMA**" → Click **Open connector page** → **Create data collection rule**

**Via Azure CLI:**
```bash
# Note: Sentinel connectors are typically configured via Portal or ARM templates
# The DCRs created below will be automatically recognized by Sentinel when properly configured

# Verify Sentinel workspace has SecurityInsights solution enabled
az monitor log-analytics solution show \
  --resource-group "<rg>" \
  --name "SecurityInsights(mips-sentinel-log-analytics)"
```

#### Step 2: Create Data Collection Rules

**DCR 1: Windows Security Events (Critical for Sentinel)**

```bash
# Create DCR for Windows Security Events
az monitor data-collection rule create \
  --resource-group "<rg>" \
  --name "dcr-sentinel-security-events" \
  --location "<location>" \
  --data-flows "[{
    \"streams\": [\"Microsoft-SecurityEvent\"],
    \"destinations\": [\"mips-sentinel-log-analytics\"]
  }]" \
  --destinations "{
    \"logAnalytics\": [{
      \"workspaceResourceId\": \"/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.OperationalInsights/workspaces/mips-sentinel-log-analytics\",
      \"name\": \"mips-sentinel-log-analytics\"
    }]
  }" \
  --data-sources "{
    \"windowsEventLogs\": [{
      \"streams\": [\"Microsoft-SecurityEvent\"],
      \"xPathQueries\": [\"Security!*\"],
      \"name\": \"securityEvents\"
    }]
  }"
```

**DCR 2: Linux Syslog (Critical for Sentinel)**

```bash
az monitor data-collection rule create \
  --resource-group "<rg>" \
  --name "dcr-sentinel-syslog" \
  --location "<location>" \
  --data-flows "[{
    \"streams\": [\"Microsoft-Syslog\"],
    \"destinations\": [\"mips-sentinel-log-analytics\"]
  }]" \
  --destinations "{
    \"logAnalytics\": [{
      \"workspaceResourceId\": \"/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.OperationalInsights/workspaces/mips-sentinel-log-analytics\",
      \"name\": \"mips-sentinel-log-analytics\"
    }]
  }" \
  --data-sources "{
    \"syslog\": [{
      \"streams\": [\"Microsoft-Syslog\"],
      \"facilityNames\": [\"auth\", \"authpriv\", \"cron\", \"daemon\", \"kern\", \"syslog\", \"user\"],
      \"logLevels\": [\"Debug\", \"Info\", \"Notice\", \"Warning\", \"Error\", \"Critical\", \"Alert\", \"Emergency\"],
      \"name\": \"syslogDataSource\"
    }]
  }"
```

**DCR 3: Performance Counters**

```bash
az monitor data-collection rule create \
  --resource-group "<rg>" \
  --name "dcr-performance-counters" \
  --location "<location>" \
  --data-flows "[{
    \"streams\": [\"Microsoft-Perf\"],
    \"destinations\": [\"mips-sentinel-log-analytics\"]
  }]" \
  --destinations "{
    \"logAnalytics\": [{
      \"workspaceResourceId\": \"/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.OperationalInsights/workspaces/mips-sentinel-log-analytics\",
      \"name\": \"mips-sentinel-log-analytics\"
    }]
  }" \
  --data-sources "{
    \"performanceCounters\": [{
      \"streams\": [\"Microsoft-Perf\"],
      \"samplingFrequencyInSeconds\": 60,
      \"counterSpecifiers\": [
        \"\\Processor Information(_Total)\\% Processor Time\",
        \"\\Memory\\Available Bytes\",
        \"\\LogicalDisk(_Total)\\% Free Space\",
        \"\\Network Interface(*)\\Bytes Total/sec\"
      ],
      \"name\": \"perfCounterDataSource\"
    }]
  }"
```

### 4.3 Phase 2: Pilot Deployment (Week 2)

| Step | Action | Owner | Duration |
|------|--------|-------|----------|
| 1 | Select 2-3 pilot VMs (mix of Windows/Linux) | | 30 min |
| 2 | Install AMA on pilot VMs (keep MMA running) | | 30 min |
| 3 | Associate DCRs with pilot VMs | | 15 min |
| 4 | Validate data ingestion (both agents sending) | | 2 hours |
| 5 | Compare data completeness MMA vs AMA | | 4 hours |
| 6 | Test Sentinel alerts trigger correctly | | 2 hours |
| 7 | Remove MMA from pilot VMs | | 30 min |
| 8 | Monitor pilot VMs for 48 hours | | 48 hours |
| 9 | Document any issues and remediations | | 1 hour |

**Install AMA on Windows VM:**
```bash
az vm extension set \
  --resource-group "<rg>" \
  --vm-name "<vm-name>" \
  --name AzureMonitorWindowsAgent \
  --publisher Microsoft.Azure.Monitor \
  --enable-auto-upgrade true
```

**Install AMA on Linux VM:**
```bash
az vm extension set \
  --resource-group "<rg>" \
  --vm-name "<vm-name>" \
  --name AzureMonitorLinuxAgent \
  --publisher Microsoft.Azure.Monitor \
  --enable-auto-upgrade true
```

**Associate DCR with VM (DCRA):**
```bash
az monitor data-collection rule association create \
  --name "<association-name>" \
  --resource "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Compute/virtualMachines/<vm-name>" \
  --rule-id "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Insights/dataCollectionRules/dcr-sentinel-security-events"
```

### 4.4 Phase 3: Production Rollout (Week 3-4)

| Step | Action | Owner | Duration |
|------|--------|-------|----------|
| 1 | Group VMs by customer/environment | | 1 hour |
| 2 | Schedule rolling deployment (10-20 VMs per batch) | | - |
| 3 | Deploy AMA to batch (parallel with MMA) | | 30 min/batch |
| 4 | Associate DCRs with batch | | 15 min/batch |
| 5 | Validate data ingestion for batch | | 1 hour/batch |
| 6 | Wait 24 hours before removing MMA | | 24 hours |
| 7 | Remove MMA from validated batch | | 30 min/batch |
| 8 | Repeat for next batch | | - |

**Bulk AMA Deployment Script (with error handling and logging):**
```bash
#!/bin/bash
# deploy_ama_batch.sh
# Enhanced with error handling, logging, and validation

set -euo pipefail

# Configuration
RESOURCE_GROUP="<rg>"
SUBSCRIPTION="<sub>"
VMS=("vm1" "vm2" "vm3" "vm4" "vm5")
DCR_SECURITY="/subscriptions/${SUBSCRIPTION}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Insights/dataCollectionRules/dcr-sentinel-security-events"
DCR_PERF="/subscriptions/${SUBSCRIPTION}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Insights/dataCollectionRules/dcr-performance-counters"
DCR_SYSLOG="/subscriptions/${SUBSCRIPTION}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Insights/dataCollectionRules/dcr-sentinel-syslog"

# Logging setup
LOG_FILE="ama_deployment_$(date +%Y%m%d_%H%M%S).log"
FAILED_VMS=()
SUCCESS_VMS=()

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== AMA Deployment Started ==="
log "Resource Group: $RESOURCE_GROUP"
log "VMs to process: ${#VMS[@]}"

for VM in "${VMS[@]}"; do
  log "--- Processing: $VM ---"

  # Verify VM exists and is running
  VM_STATE=$(az vm get-instance-view -g "$RESOURCE_GROUP" -n "$VM" --query "instanceView.statuses[1].displayStatus" -o tsv 2>/dev/null || echo "NotFound")

  if [ "$VM_STATE" == "NotFound" ]; then
    log "[ERROR] VM $VM not found in resource group $RESOURCE_GROUP"
    FAILED_VMS+=("$VM:NotFound")
    continue
  fi

  if [ "$VM_STATE" != "VM running" ]; then
    log "[WARN] VM $VM is not running (state: $VM_STATE). Skipping..."
    FAILED_VMS+=("$VM:NotRunning")
    continue
  fi

  # Verify managed identity is enabled
  MI_ENABLED=$(az vm show -g "$RESOURCE_GROUP" -n "$VM" --query "identity.type" -o tsv 2>/dev/null || echo "None")
  if [ "$MI_ENABLED" == "None" ] || [ -z "$MI_ENABLED" ]; then
    log "[ERROR] VM $VM does not have managed identity enabled. Run: az vm identity assign -g $RESOURCE_GROUP -n $VM"
    FAILED_VMS+=("$VM:NoManagedIdentity")
    continue
  fi

  # Detect OS and install appropriate agent
  OS_TYPE=$(az vm show -g "$RESOURCE_GROUP" -n "$VM" --query "storageProfile.osDisk.osType" -o tsv)
  log "OS Type: $OS_TYPE"

  if [ "$OS_TYPE" == "Windows" ]; then
    log "Installing AzureMonitorWindowsAgent..."
    if ! az vm extension set -g "$RESOURCE_GROUP" --vm-name "$VM" \
      --name AzureMonitorWindowsAgent \
      --publisher Microsoft.Azure.Monitor \
      --enable-auto-upgrade true 2>&1 | tee -a "$LOG_FILE"; then
      log "[ERROR] Failed to install AMA on $VM"
      FAILED_VMS+=("$VM:ExtensionFailed")
      continue
    fi

    # Associate Windows-specific DCRs
    VM_ID="/subscriptions/${SUBSCRIPTION}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Compute/virtualMachines/$VM"

    log "Associating security DCR..."
    az monitor data-collection rule association create \
      --name "${VM}-security-dcra" \
      --resource "$VM_ID" \
      --rule-id "$DCR_SECURITY" 2>&1 | tee -a "$LOG_FILE" || log "[WARN] Security DCR association may already exist"

    log "Associating performance DCR..."
    az monitor data-collection rule association create \
      --name "${VM}-perf-dcra" \
      --resource "$VM_ID" \
      --rule-id "$DCR_PERF" 2>&1 | tee -a "$LOG_FILE" || log "[WARN] Perf DCR association may already exist"

  else
    log "Installing AzureMonitorLinuxAgent..."
    if ! az vm extension set -g "$RESOURCE_GROUP" --vm-name "$VM" \
      --name AzureMonitorLinuxAgent \
      --publisher Microsoft.Azure.Monitor \
      --enable-auto-upgrade true 2>&1 | tee -a "$LOG_FILE"; then
      log "[ERROR] Failed to install AMA on $VM"
      FAILED_VMS+=("$VM:ExtensionFailed")
      continue
    fi

    # Associate Linux-specific DCRs
    VM_ID="/subscriptions/${SUBSCRIPTION}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Compute/virtualMachines/$VM"

    log "Associating syslog DCR..."
    az monitor data-collection rule association create \
      --name "${VM}-syslog-dcra" \
      --resource "$VM_ID" \
      --rule-id "$DCR_SYSLOG" 2>&1 | tee -a "$LOG_FILE" || log "[WARN] Syslog DCR association may already exist"

    log "Associating performance DCR..."
    az monitor data-collection rule association create \
      --name "${VM}-perf-dcra" \
      --resource "$VM_ID" \
      --rule-id "$DCR_PERF" 2>&1 | tee -a "$LOG_FILE" || log "[WARN] Perf DCR association may already exist"
  fi

  log "[SUCCESS] Completed: $VM"
  SUCCESS_VMS+=("$VM")
done

# Summary
log "=== Deployment Summary ==="
log "Successful: ${#SUCCESS_VMS[@]} VMs"
log "Failed: ${#FAILED_VMS[@]} VMs"

if [ ${#FAILED_VMS[@]} -gt 0 ]; then
  log "Failed VMs: ${FAILED_VMS[*]}"
  log "Review $LOG_FILE for details"
  exit 1
fi

log "=== AMA Deployment Completed Successfully ==="
```

### 4.5 Phase 4: MMA Removal (Week 4-5)

| Step | Action | Owner | Duration |
|------|--------|-------|----------|
| 1 | Confirm AMA data flowing for all VMs (24h+ data) | | 2 hours |
| 2 | Run Sentinel validation queries | | 2 hours |
| 3 | Remove MMA from all Windows VMs | | 2 hours |
| 4 | Remove MMA from all Linux VMs | | 2 hours |
| 5 | Verify no MMA heartbeats in workspace | | 1 hour |
| 6 | Update CMDB and documentation | | 2 hours |

**Remove MMA from Windows:**
```bash
az vm extension delete \
  --resource-group "<rg>" \
  --vm-name "<vm-name>" \
  --name MicrosoftMonitoringAgent
```

**Remove MMA from Linux:**
```bash
az vm extension delete \
  --resource-group "<rg>" \
  --vm-name "<vm-name>" \
  --name OmsAgentForLinux
```

### 4.6 Phase 5: Network Monitoring Migration (Separate Track)

> **Note**: NetworkMonitoring solution uses Network Performance Monitor (NPM) which is being deprecated. This requires migration to **Connection Monitor** in Azure Network Watcher - this is independent of the AMA migration.

| Step | Action | Owner | Duration |
|------|--------|-------|----------|
| 1 | Audit current NPM tests and thresholds | | 4 hours |
| 2 | Create equivalent Connection Monitor tests | | 4 hours |
| 3 | Run parallel monitoring (NPM + Connection Monitor) | | 1 week |
| 4 | Validate alerting parity | | 2 hours |
| 5 | Disable NPM solution | | 1 hour |

---

## 5. Verification Plan

### 5.1 Data Ingestion Verification

| Check | KQL Query | Expected Result | Pass/Fail |
|-------|-----------|-----------------|-----------|
| AMA Heartbeat | See below | All VMs reporting | ☐ |
| Security Events | See below | Events from all Windows VMs | ☐ |
| Syslog | See below | Events from all Linux VMs | ☐ |
| Performance Data | See below | Counters from all VMs | ☐ |

**AMA Heartbeat Query:**
```kusto
Heartbeat
| where TimeGenerated > ago(1h)
| where Category == "Azure Monitor Agent"
| summarize LastHeartbeat = max(TimeGenerated) by Computer
| order by Computer asc
```

**Security Events Query:**
```kusto
SecurityEvent
| where TimeGenerated > ago(1h)
| summarize EventCount = count() by Computer
| order by EventCount desc
```

**Syslog Query:**
```kusto
Syslog
| where TimeGenerated > ago(1h)
| summarize EventCount = count() by Computer
| order by EventCount desc
```

**No MMA Remaining Query:**
```kusto
Heartbeat
| where TimeGenerated > ago(24h)
| where Category == "Direct Agent"
| summarize LastHeartbeat = max(TimeGenerated) by Computer
// Should return 0 results after MMA removal
```

**MMA vs AMA Data Parity Comparison (use during parallel phase):**
```kusto
// Compare event counts between MMA and AMA during parallel running
// Run this to validate AMA is collecting same data as MMA before removing MMA

// Security Events Comparison
SecurityEvent
| where TimeGenerated > ago(1h)
| extend AgentType = case(
    Category == "Direct Agent", "MMA",
    Category == "Azure Monitor Agent", "AMA",
    "Unknown"
)
| summarize EventCount = count() by AgentType, Computer
| order by Computer, AgentType

// Syslog Comparison (Linux)
Syslog
| where TimeGenerated > ago(1h)
| extend AgentType = case(
    Category == "Direct Agent", "MMA",
    Category == "Azure Monitor Agent", "AMA",
    "Unknown"
)
| summarize EventCount = count() by AgentType, Computer
| order by Computer, AgentType

// Performance Counter Comparison
Perf
| where TimeGenerated > ago(1h)
| extend AgentType = case(
    Category == "Direct Agent", "MMA",
    Category == "Azure Monitor Agent", "AMA",
    "Unknown"
)
| summarize CounterCount = count() by AgentType, Computer
| order by Computer, AgentType
```

**Data Parity Validation Summary:**
```kusto
// Summary view - should show roughly equal counts for MMA vs AMA per VM
Heartbeat
| where TimeGenerated > ago(1h)
| summarize
    MMA_Heartbeats = countif(Category == "Direct Agent"),
    AMA_Heartbeats = countif(Category == "Azure Monitor Agent")
    by Computer
| extend ParityStatus = iff(MMA_Heartbeats > 0 and AMA_Heartbeats > 0, "✅ Both Active", "⚠️ Check Agent")
| project Computer, MMA_Heartbeats, AMA_Heartbeats, ParityStatus
```

### 5.2 Sentinel Functionality Verification

| Check | Method | Expected Result | Pass/Fail |
|-------|--------|-----------------|-----------|
| Analytics rules firing | Sentinel > Analytics | Rules showing recent runs | ☐ |
| Incidents being created | Sentinel > Incidents | New incidents from AMA data | ☐ |
| Workbooks rendering | Sentinel > Workbooks | Data populating correctly | ☐ |
| Hunting queries working | Sentinel > Hunting | Queries return results | ☐ |
| Playbooks triggering | Sentinel > Automation | Playbooks execute on incidents | ☐ |

### 5.3 Solution-Specific Verification

| Solution | Verification Method | Pass/Fail |
|----------|---------------------|-----------|
| SecurityInsights | Incidents created, analytics rules run | ☐ |
| LogicAppsManagement | Playbooks execute successfully | ☐ |
| NetworkMonitoring | Connection Monitor tests passing (if migrated) | ☐ |
| SecurityCenterFree | Defender recommendations visible | ☐ |

---

## 6. Rollback Plan

### 6.1 Rollback Triggers

Initiate rollback if:
- AMA fails to install on >20% of VMs
- Critical Sentinel alerts stop firing for >1 hour
- Data ingestion drops by >50% compared to MMA baseline
- Security team reports visibility gaps
- Performance impact on VMs (>10% CPU increase from agent)

### 6.2 Rollback Procedure

**Scenario A: AMA not working, MMA still installed (Parallel phase)**
- No action needed - MMA continues to send data
- Troubleshoot AMA issues before proceeding

**Scenario B: MMA already removed, need to reinstall**

```bash
# Reinstall MMA on Windows
WORKSPACE_ID="<workspace-id>"
WORKSPACE_KEY="<workspace-key>"

az vm extension set \
  --resource-group "<rg>" \
  --vm-name "<vm-name>" \
  --name MicrosoftMonitoringAgent \
  --publisher Microsoft.EnterpriseCloud.Monitoring \
  --settings "{\"workspaceId\":\"$WORKSPACE_ID\"}" \
  --protected-settings "{\"workspaceKey\":\"$WORKSPACE_KEY\"}"

# Reinstall MMA on Linux
az vm extension set \
  --resource-group "<rg>" \
  --vm-name "<vm-name>" \
  --name OmsAgentForLinux \
  --publisher Microsoft.EnterpriseCloud.Monitoring \
  --settings "{\"workspaceId\":\"$WORKSPACE_ID\"}" \
  --protected-settings "{\"workspaceKey\":\"$WORKSPACE_KEY\"}"
```

### 6.3 Rollback Timeline

| Phase | Rollback Complexity | Time to Recover |
|-------|---------------------|-----------------|
| Pilot (MMA still present) | Simple - disable AMA | 15 minutes |
| Production (MMA still present) | Simple - disable AMA | 30 minutes |
| Post-MMA removal | Complex - reinstall MMA | 2-4 hours |

---

## 7. Cost Impact Analysis

### 7.1 Parallel Running Phase (Temporary)

During the parallel running phase, both MMA and AMA will send data to Log Analytics, resulting in temporary cost increase.

| Cost Factor | Impact | Duration | Mitigation |
|-------------|--------|----------|------------|
| Log Ingestion | **~2x normal rate** | 24-48 hours per batch | Minimize parallel window |
| Data Duplication | SecurityEvent, Syslog, Perf sent twice | 2-3 weeks total | Expected and acceptable |
| Estimated Additional | ~$X per GB × daily ingestion volume | Migration period | Budget accordingly |

**Cost Estimation Query:**
```kusto
// Calculate current daily ingestion to estimate parallel phase cost
Usage
| where TimeGenerated > ago(7d)
| where DataType in ("SecurityEvent", "Syslog", "Perf", "Event")
| summarize DailyGB = sum(Quantity) / 7 by DataType
| extend ParallelCostEstimate = DailyGB * 2 * 2.76 // $2.76/GB ingestion rate (adjust for your pricing)
| project DataType, DailyGB, ParallelCostEstimate
```

### 7.2 Post-Migration (Steady State)

| Cost Factor | Before (MMA) | After (AMA) | Change |
|-------------|--------------|-------------|--------|
| Agent License | Free | Free | None |
| Log Ingestion | Baseline | Baseline | None |
| DCR Management | N/A | Free | None |
| **Total Operational** | Baseline | Baseline | **No change** |

---

## 8. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| AMA fails to collect all event types | Low | High | Parallel running validates parity before MMA removal |
| Sentinel rules break due to schema differences | Very Low | High | Schema is identical; test rules on pilot VMs first |
| VM performance degradation | Low | Medium | Monitor VM metrics; AMA is typically lighter than MMA |
| DCR misconfiguration misses data | Medium | High | Review DCR coverage against MMA config; validate with queries |
| **Managed identity not configured** | **Medium** | **High** | **Pre-configure system-assigned MI + RBAC on all VMs (Phase 0)** |
| **Network connectivity blocked** | **Medium** | **High** | **Validate AMA endpoint connectivity before deployment** |
| Customer change window conflicts | Medium | Low | Schedule per-customer; can pause between batches |
| Network Monitoring gaps | Medium | Medium | Separate migration track; maintain NPM until Connection Monitor validated |
| **Parallel phase cost overrun** | Low | Low | Budget for 2x ingestion during parallel phase |

---

## 9. Communication Plan

| When | Who | What |
|------|-----|------|
| 2 weeks before | All stakeholders | Migration announcement and timeline |
| 1 week before | Security team | Sentinel validation plan review |
| Per batch | Affected customer contacts | Batch deployment notification |
| Daily during rollout | IT Team, Security | Progress update |
| Post-migration | All stakeholders | Completion confirmation, Sentinel health status |
| +1 week | Security team | Post-migration security review |

---

## 10. Approvals

| Role | Name | Date | Approval |
|------|------|------|----------|
| Change Requester | Olli Ojala | | |
| Security Team Lead | | | |
| Technical Reviewer | | | |
| Customer Success (if applicable) | | | |
| Change Manager | | | |
| CAB | | | |

---

## 11. Implementation Checklist

### Pre-Migration
- [ ] VM inventory complete (Windows: ___, Linux: ___)
- [ ] Current MMA configuration documented
- [ ] Sentinel analytics rules audited
- [ ] **System-assigned managed identity enabled on all VMs**
- [ ] **RBAC role (Monitoring Metrics Publisher) assigned to all VM identities**
- [ ] **Network connectivity to AMA endpoints validated**
- [ ] DCRs created and tested
- [ ] **Sentinel AMA-based connectors enabled**
- [ ] Rollback procedures documented
- [ ] Customer maintenance windows scheduled
- [ ] **Workspace key stored securely in Key Vault (for rollback)**

### Pilot Phase
- [ ] Pilot VMs selected and documented
- [ ] AMA installed on pilot VMs
- [ ] DCRs associated with pilot VMs
- [ ] **MMA vs AMA data parity validated using comparison queries**
- [ ] **Event counts match within acceptable variance (<5%)**
- [ ] Sentinel alerts tested and firing correctly
- [ ] MMA removed from pilot VMs
- [ ] 48-hour monitoring complete
- [ ] **No data gaps detected post-MMA removal**

### Production Rollout
- [ ] Batch schedule created
- [ ] Per-batch AMA deployment complete
- [ ] Per-batch DCR association complete
- [ ] Per-batch validation complete
- [ ] 24-hour parallel running complete
- [ ] Per-batch MMA removal complete

### Post-Migration
- [ ] All VMs migrated to AMA
- [ ] All MMA extensions removed
- [ ] Sentinel fully validated
- [ ] Network Monitoring migration planned/complete
- [ ] Documentation updated
- [ ] CMDB updated
- [ ] Change request closed

---

## 12. References

### Microsoft Documentation
- [MMA to AMA Migration Guide](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-migration)
- [AMA Overview](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/agents-overview)
- [Data Collection Rules](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-overview)
- [Sentinel and AMA](https://learn.microsoft.com/en-us/azure/sentinel/connect-services-api-based)
- [Network Performance Monitor Deprecation](https://learn.microsoft.com/en-us/azure/network-watcher/migrate-to-connection-monitor-from-network-performance-monitor)

### Tools
- [AMA Migration Helper Workbook](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-migration-tools)
- [DCR Generator](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-migration-tools#dcr-generator)

---

*Document Version: 2.0*
*Previous Version: 1.0 (MMA Version Update Only)*
*Change: Pivoted to full MMA → AMA Migration*
*Last Updated: [Date]*
