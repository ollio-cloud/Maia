# Azure Virtual Desktop Autoscaling Configuration Guide
## SSGroup - ssg-avd-pool-001

**Purpose**: Step-by-step instructions to optimize AVD autoscaling and reduce empty host hours
**Estimated Time**: 30-45 minutes
**Prerequisites**: Azure Portal access with Contributor rights to AVD resources

---

## Table of Contents

1. [Current State Assessment](#1-current-state-assessment)
2. [Create or Update Scaling Plan](#2-create-or-update-scaling-plan)
3. [Configure Scaling Schedules](#3-configure-scaling-schedules)
4. [Assign Scaling Plan to Host Pool](#4-assign-scaling-plan-to-host-pool)
5. [Investigate AZHOST-2 Idle Issue](#5-investigate-azhost-2-idle-issue)
6. [Validation and Monitoring](#6-validation-and-monitoring)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Current State Assessment

### Before Making Changes

1. **Document Current Configuration**
   - Navigate to: Azure Portal → Azure Virtual Desktop → Scaling plans
   - Screenshot or note current settings
   - Record any existing schedules

2. **Verify Host Pool Settings**
   - Navigate to: Azure Portal → Azure Virtual Desktop → Host pools → ssg-avd-pool-001
   - Check: Properties → Max session limit per host
   - Note current value: ______ (recommended: 12 for D4s_v5, 24 for D8s_v5)

3. **Check Session Host Status**
   - Navigate to: Host pools → ssg-avd-pool-001 → Session hosts
   - Verify all 3 hosts are showing "Available" or "Running"

---

## 2. Create or Update Scaling Plan

### Navigate to Scaling Plans

```
Azure Portal → Azure Virtual Desktop → Scaling plans
```

### Create New Scaling Plan (if none exists)

1. Click **+ Create**
2. Fill in basics:

| Field | Value |
|-------|-------|
| Subscription | Your subscription |
| Resource group | Same as host pool |
| Name | `ssg-avd-scaling-plan-001` |
| Location | Australia East |
| Friendly name | SSG AVD Autoscaling |
| Time zone | **(GMT+10:00) Canberra, Melbourne, Sydney** |

3. Click **Next: Schedules**

### If Scaling Plan Exists

1. Click on existing scaling plan
2. Go to **Schedules** in left menu
3. Edit or add schedule (continue to Section 3)

---

## 3. Configure Scaling Schedules

### Recommended Schedule Configuration

Based on your usage analysis (peak 06:00-17:00 AEST), configure the following:

---

### Schedule 1: Weekday Schedule

Click **+ Add schedule** and configure:

#### General Tab

| Setting | Value |
|---------|-------|
| Schedule name | `Weekday-BusinessHours` |
| Days | Monday, Tuesday, Wednesday, Thursday, Friday |

#### Ramp-Up Tab

| Setting | Value | Explanation |
|---------|-------|-------------|
| Start time | **06:00** | Start scaling up before business hours |
| Load balancing algorithm | Breadth-first | Spread users across hosts |
| Minimum percentage of hosts | **33%** | 1 of 3 hosts minimum |
| Capacity threshold | **75%** | Scale up when 75% full |

#### Peak Hours Tab

| Setting | Value | Explanation |
|---------|-------|-------------|
| Start time | **08:00** | Core business hours begin |
| Load balancing algorithm | Breadth-first | Even distribution |
| Minimum percentage of hosts | **66%** | 2 of 3 hosts minimum (handles peak of 13) |
| Capacity threshold | **75%** | Scale up when hosts 75% utilized |

#### Ramp-Down Tab (CRITICAL FOR COST SAVINGS)

| Setting | Value | Explanation |
|---------|-------|-------------|
| Start time | **17:00** | Business hours ending |
| Load balancing algorithm | Depth-first | Consolidate users to fewer hosts |
| Minimum percentage of hosts | **33%** | Allow reduction to 1 host |
| Capacity threshold | **90%** | Only scale up if nearly full |
| Force logoff users | No | Don't disconnect active users |
| Wait time (minutes) | **15** | **REDUCE FROM DEFAULT** - faster scale-down |
| Stop hosts when | Sessions = 0 | Deallocate when empty |

#### Off-Peak Tab

| Setting | Value | Explanation |
|---------|-------|-------------|
| Start time | **19:00** | Well after business hours |
| Load balancing algorithm | Depth-first | Consolidate |
| Minimum percentage of hosts | **33%** | **1 host minimum** |
| Capacity threshold | **90%** | Conservative scaling |
| Stop hosts when | Sessions = 0 | Deallocate empty hosts |

---

### Schedule 2: Weekend Schedule (Optional - Maximum Savings)

If weekend usage is acceptable at reduced capacity:

Click **+ Add schedule** and configure:

#### General Tab

| Setting | Value |
|---------|-------|
| Schedule name | `Weekend-Minimal` |
| Days | Saturday, Sunday |

#### All Time Periods

| Setting | Value |
|---------|-------|
| Minimum percentage of hosts | **33%** (1 host) |
| Load balancing algorithm | Depth-first |
| Capacity threshold | **90%** |
| Stop hosts when | Sessions = 0 |

**Alternative**: Set minimum to **0%** if zero weekend availability is acceptable (hosts start on-demand when user connects).

---

### Visual Schedule Summary

```
WEEKDAY SCHEDULE (Mon-Fri)

Hour:  00  02  04  06  08  10  12  14  16  18  20  22  24
       |---|---|---|---|---|---|---|---|---|---|---|---|

Hosts: [1] [1] [1] [1] [2--------2--------2] [1] [1] [1]
                    ↑               ↑           ↑
                 Ramp-Up         Peak      Ramp-Down/Off-Peak
                 06:00          08:00         17:00/19:00

Min hosts:  1 host (33%)    2 hosts (66%)    1 host (33%)
```

---

## 4. Assign Scaling Plan to Host Pool

### Link Scaling Plan to Host Pool

1. In the scaling plan, go to **Host pool assignments**
2. Click **+ Assign**
3. Select: `ssg-avd-pool-001`
4. Enable scaling: **Yes**
5. Click **Save**

### Verify Assignment

1. Navigate to: Host pools → ssg-avd-pool-001 → Scaling plan
2. Confirm scaling plan is assigned and enabled

---

## 5. Investigate AZHOST-2 Idle Issue

AZHOST-2 had **404 empty hours (56% idle)** - this requires investigation.

### Check 1: Drain Mode Status

1. Navigate to: Host pools → ssg-avd-pool-001 → Session hosts
2. Find **SSG-AZHOST-2.ssg.local**
3. Check the **Status** column:
   - If **"Drain mode"**: Host won't accept new connections but stays on
   - Click host → Set drain mode to **Off**

### Check 2: User Assignments (Personal Desktop Scenario)

1. Click on **SSG-AZHOST-2.ssg.local**
2. Go to **Assigned users**
3. If users are directly assigned:
   - This keeps the host running even when user is offline
   - Consider removing direct assignments for pooled model

### Check 3: Scaling Plan Exclusion

1. Navigate to: Scaling plan → Host pool assignments
2. Verify ssg-avd-pool-001 is assigned
3. Check no host-level exclusions exist

### Check 4: Maintenance Tags

```
Azure Portal → Virtual Machines → SSG-AZHOST-2
→ Tags
```

Look for tags like:
- `ExcludeFromScaling: true`
- `AlwaysOn: true`

Remove if present and not needed.

### Check 5: Azure Advisor

```
Azure Portal → Advisor → Cost recommendations
```

Look for recommendations related to idle VMs.

---

## 6. Validation and Monitoring

### Immediate Validation (Day 1)

After applying changes, monitor:

1. **Session Host Status**
   ```
   Host pools → ssg-avd-pool-001 → Session hosts
   ```
   - Watch hosts transition between "Running" and "Deallocated"
   - Verify at least 1 host stays available

2. **Test User Connection**
   - Have a user connect during off-peak
   - Verify they can connect successfully
   - Check if additional hosts spin up if needed

### Daily Monitoring (Week 1)

Run this KQL query daily to track improvement:

```kusto
// Track empty hours trend
WVDAgentHealthStatus
| where TimeGenerated > ago(1d)
| where Status == "Available"
| summarize AvailableHours = dcount(bin(TimeGenerated, 1h)) by SessionHostName
| join kind=leftanti (
    WVDConnections
    | where TimeGenerated > ago(1d)
    | where State == "Connected"
    | summarize by SessionHostName, bin(TimeGenerated, 1h)
) on SessionHostName
| summarize EmptyHours = count() by SessionHostName
```

**Target**: Reduce empty hours from 603/month to <100/month

### Weekly Review (Month 1)

Compare metrics before and after:

| Metric | Before | After | Target |
|--------|--------|-------|--------|
| Empty hours/month | 603 | ? | <100 |
| AZHOST-2 idle % | 56% | ? | <15% |
| Estimated waste | $115-229 | ? | <$30 |

---

## 7. Troubleshooting

### Issue: Hosts Not Scaling Down

**Symptoms**: Hosts remain running even with zero sessions

**Solutions**:
1. Check ramp-down wait time (reduce to 15 min)
2. Verify "Stop hosts when" = "Sessions = 0"
3. Check for disconnected (not logged off) sessions:
   ```kusto
   WVDConnections
   | where TimeGenerated > ago(1h)
   | where State == "Disconnected"
   | summarize by SessionHostName, UserName
   ```

### Issue: Hosts Not Starting When Needed

**Symptoms**: Users can't connect, no available hosts

**Solutions**:
1. Increase minimum percentage of hosts
2. Check capacity threshold (lower if too aggressive)
3. Verify host pool has available licenses

### Issue: Slow Host Startup

**Symptoms**: Users wait too long for host to start

**Solutions**:
1. Use **Hibernate** instead of Deallocate (faster resume, but costs more)
2. Increase minimum hosts during ramp-up period
3. Start ramp-up earlier (e.g., 05:30 instead of 06:00)

### Issue: Users Disconnected Unexpectedly

**Symptoms**: Active users lose connection

**Check**:
1. Ensure "Force logoff users" = **No** in ramp-down
2. Verify wait time allows users to complete work
3. Check session time limits aren't too aggressive

---

## Quick Reference Card

### Optimal Settings for SSGroup

```
┌─────────────────────────────────────────────────────────┐
│  SSG AVD AUTOSCALING - QUICK REFERENCE                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  WEEKDAY SCHEDULE                                       │
│  ├── Ramp-Up (06:00): Min 33% (1 host)                 │
│  ├── Peak (08:00):    Min 66% (2 hosts)                │
│  ├── Ramp-Down (17:00): Min 33%, Wait 15 min           │
│  └── Off-Peak (19:00): Min 33% (1 host)                │
│                                                         │
│  WEEKEND SCHEDULE                                       │
│  └── All day: Min 33% (1 host)                         │
│                                                         │
│  KEY SETTINGS                                           │
│  ├── Load balancing: Breadth-first (peak)              │
│  ├── Load balancing: Depth-first (ramp-down/off-peak)  │
│  ├── Stop hosts when: Sessions = 0                     │
│  └── Ramp-down wait: 15 minutes                        │
│                                                         │
│  EXPECTED RESULTS                                       │
│  ├── Empty hours: 603 → <100 per month                 │
│  ├── Cost savings: $115-229 per month                  │
│  └── User experience: No impact                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Post-Implementation Checklist

- [ ] Documented current autoscaling configuration
- [ ] Created/updated scaling plan with recommended schedules
- [ ] Assigned scaling plan to ssg-avd-pool-001
- [ ] Investigated AZHOST-2 idle issue
- [ ] Tested user connection during off-peak
- [ ] Set up monitoring query for empty hours
- [ ] Scheduled 1-week review meeting

---

**Document Version**: 1.0
**Created**: January 2026
**Author**: Azure Architect Agent
**Next Review**: After 1-week validation period
