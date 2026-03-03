# Azure Virtual Desktop Technical Assessment Report
## SSGroup Environment Analysis

**Report Date**: January 2026
**Analysis Period**: 30 Days
**Host Pool**: ssg-avd-pool-001
**Prepared by**: Azure Architect Agent

---

## Table of Contents

1. [Environment Overview](#1-environment-overview)
2. [Session Host Utilization](#2-session-host-utilization)
3. [Usage Patterns](#3-usage-patterns)
4. [User Activity Analysis](#4-user-activity-analysis)
5. [Capacity Assessment](#5-capacity-assessment)
6. [Waste Identification](#6-waste-identification)
7. [Recommendations](#7-recommendations)
8. [Implementation Roadmap](#8-implementation-roadmap)

---

## 1. Environment Overview

### Infrastructure Summary

| Component | Details |
|-----------|---------|
| **Host Pool** | ssg-avd-pool-001 |
| **Pool Type** | Pooled (shared) |
| **Session Hosts** | 3 |
| **VM Series** | D-series (D4s_v5 / D8s_v5) |
| **Domain** | ssg.local |
| **Scaling** | Autoscaling enabled |
| **Monitoring** | Log Analytics connected |

### Session Hosts

| Host Name | Status |
|-----------|--------|
| SSG-AZHOST-0.ssg.local | Active |
| SSG-AZHOST-1.ssg.local | Active |
| SSG-AZHOST-2.ssg.local | Active (high idle time) |

---

## 2. Session Host Utilization

### Per-Host Metrics (30 Days)

| Host | Avg Sessions | Max Sessions | Min Sessions | Empty Hours | Idle % |
|------|--------------|--------------|--------------|-------------|--------|
| SSG-AZHOST-0 | 2.16 | 9 | 1 | 134 | 19% |
| SSG-AZHOST-1 | 2.28 | 7 | 1 | 65 | 9% |
| SSG-AZHOST-2 | 2.51 | 13 | 1 | **404** | **56%** |
| **Average** | **2.32** | - | - | **201** | **28%** |

### Key Findings

1. **Low Average Utilization**: 2.32 sessions per host average indicates significant over-provisioning
2. **AZHOST-2 Anomaly**: 404 empty hours (56% of month) suggests misconfiguration or exclusion from autoscaling
3. **Uneven Distribution**: AZHOST-2 handles highest peak (13) but also has most idle time

---

## 3. Usage Patterns

### Hourly Distribution (UTC)

| Time Block (UTC) | Typical Sessions | Local Time (AEST) | Classification |
|------------------|------------------|-------------------|----------------|
| 19:00 - 23:00 | 6-17 | 05:00-09:00 | Ramp-Up |
| 00:00 - 05:00 | 7-24 | 10:00-15:00 | Peak |
| 06:00 - 08:00 | 1-5 | 16:00-18:00 | Ramp-Down |
| 09:00 - 18:00 | 0-2 | 19:00-04:00 | Off-Peak |

### Peak Usage Analysis

| Metric | Value | Timing |
|--------|-------|--------|
| **Highest Peak** | 24 sessions | Tuesday 00:00 UTC (10:00 AEST Monday) |
| **Typical Peak** | 16-17 sessions | 21:00-23:00 UTC (07:00-09:00 AEST) |
| **Weekend Usage** | Near zero | 1 session Saturday |

### Usage Heat Map

```
Hour (UTC)   Sun  Mon  Tue  Wed  Thu  Fri  Sat
00:00         1   16   24    -    -    -    -
01:00         -   11   18    -    -    -    -
02:00         -    7    -    -    -    -    -
03:00         -   16    -    -    -    -    -
04:00         -    8    -    -    -    -    -
05:00         -    8    -    -    -    -    -
06:00         -    2    -    -    -    -    -
07:00         -    5    -    -    -    -    -
08:00         -    1    -    -    -    -    -
09:00         -    2    -    -    -    -    -
...
19:00         2    2    -    -    -    -    -
20:00         6   10    -    -    -    -    -
21:00        11   16    -    -    -    -    -
22:00         6   12    -    -    -    -    -
23:00        10   17    -    -    -    -    1
```

---

## 4. User Activity Analysis

### User Summary

| Category | Count | Sessions | % of Total | Description |
|----------|-------|----------|------------|-------------|
| Heavy Users | 5 | 315 | 39% | Daily usage, >1.8 sessions/day |
| Regular Users | 10 | 384 | 48% | Weekly usage, 0.5-1.5 sessions/day |
| Light Users | 11 | 103 | 13% | Occasional, <0.5 sessions/day |
| **Total** | **26** | **802** | **100%** | |

### Top 10 Users by Activity

| Rank | User | Total Sessions | Days Active | Avg/Day | Type |
|------|------|----------------|-------------|---------|------|
| 1 | craig.rosenzweig@ssgroup.com.au | 75 | 24 | 2.50 | Individual |
| 2 | railpartsnsw@ssgroup.com.au | 71 | 23 | 2.37 | **Shared** |
| 3 | cristian.cifuentes@ssgroup.com.au | 57 | 21 | 1.90 | Individual |
| 4 | serviceadmin.wa@ssgroup.com.au | 57 | 16 | 1.90 | **Service** |
| 5 | waserviceadmin@ssgroup.com.au | 55 | 19 | 1.83 | **Service** |
| 6 | Gabby.Pudelka@ssgroup.com.au | 44 | 19 | 1.47 | Individual |
| 7 | Jenifer.Robinson@ssgroup.com.au | 40 | 14 | 1.33 | Individual |
| 8 | Maddie.Halloran@ssgroup.com.au | 37 | 20 | 1.23 | Individual |
| 9 | daniella.grech@ssgroup.com.au | 36 | 16 | 1.20 | Individual |
| 10 | Shelby.Ross@ssgroup.com.au | 36 | 15 | 1.20 | Individual |

### Shared/Service Accounts Detected

| Account | Sessions | Concern |
|---------|----------|---------|
| railpartsnsw@ssgroup.com.au | 71 | Shared departmental account |
| railparts@ssgroup.com.au | 19 | Shared departmental account |
| serviceadmin.wa@ssgroup.com.au | 57 | Service account |
| waserviceadmin@ssgroup.com.au | 55 | Service account |
| reception@ssgroup.com.au | 20 | Shared reception account |

**Licensing Note**: Microsoft AVD licensing is per-user. Shared accounts may require review for compliance with licensing terms.

### Low Usage Users (Consider License Review)

| User | Sessions | Days | Notes |
|------|----------|------|-------|
| megan.jones@ssgroup.com.au | 3 | 2 | Minimal usage |
| Helen.Croft@ssgroup.com.au | 2 | 1 | Single day only |
| Anna.Horgan@ssgroup.com.au | 1 | 1 | Single session in 30 days |

---

## 5. Capacity Assessment

### Host Pool Capacity vs Demand

| Metric | Value | Assessment |
|--------|-------|------------|
| **Average Active Sessions** | 2.86 | 1 host sufficient |
| **P95 Sessions** | 7 | 1 host handles 95% of demand |
| **Peak Sessions** | 13 | 2 hosts sufficient |
| **Current Capacity (3 hosts)** | 24-36 | Over-provisioned |

### Capacity Utilization Visualization

```
Current Capacity (3 hosts D4s_v5):     ████████████████████████████████████  36 sessions
Current Capacity (3 hosts D8s_v5):     ████████████████████████████████████████████████████████████████████████  72 sessions

Peak Demand (13 sessions):             █████████████                          13 sessions
P95 Demand (7 sessions):               ███████                                 7 sessions
Average Demand (2.86 sessions):        ███                                     3 sessions

UTILIZATION:
- Average: 8-12% of capacity
- P95: 19-29% of capacity
- Peak: 36-54% of capacity
```

### Right-Sizing Recommendation

| Scenario | Hosts Needed | Rationale |
|----------|--------------|-----------|
| 95% of time (P95=7) | 1 host | Single D4s_v5 handles 8-12 users |
| Peak demand (13) | 2 hosts | Two D4s_v5 handle 16-24 users |
| Current (over-provisioned) | 3 hosts | 50% excess capacity |

---

## 6. Waste Identification

### Empty Hours Analysis

| Host | Empty Hours | % of Month | Estimated Waste (D4s_v5) | Estimated Waste (D8s_v5) |
|------|-------------|------------|--------------------------|--------------------------|
| SSG-AZHOST-2 | 404 | 56% | $77 | $154 |
| SSG-AZHOST-0 | 134 | 19% | $25 | $51 |
| SSG-AZHOST-1 | 65 | 9% | $12 | $25 |
| **Total** | **603** | **28%** | **$115** | **$229** |

### Root Cause Analysis

1. **Autoscaling Not Aggressive Enough**
   - Hosts remain running after users disconnect
   - Minimum hosts setting likely too high
   - Ramp-down wait time too long

2. **AZHOST-2 Specific Issues**
   - 404 empty hours = 56% idle
   - Possible causes:
     - Excluded from autoscaling drain mode
     - Set as "always on" for specific users
     - Configuration error in scaling plan

3. **Off-Peak Over-Provisioning**
   - Usage drops to near-zero 17:00-06:00 AEST
   - Hosts likely running through night unnecessarily

---

## 7. Recommendations

### Priority 1: Immediate (This Week)

#### 7.1 Fix Autoscaling Configuration
**Impact**: $100-200/month savings
**Effort**: 30 minutes

| Setting | Current (Likely) | Recommended |
|---------|------------------|-------------|
| Minimum hosts (off-peak) | 2-3 | **1** |
| Minimum hosts (peak) | 3 | **2** |
| Ramp-down wait time | 30+ min | **15 min** |
| Stop action | Hibernate | **Deallocate** |

#### 7.2 Investigate AZHOST-2
**Impact**: Major contributor to waste
**Effort**: 15 minutes

Check:
- Is host excluded from scaling plan?
- Is drain mode enabled but not clearing?
- Are there user assignments keeping it alive?

### Priority 2: Short-Term (This Month)

#### 7.3 Reduce Maximum Host Count
**Impact**: $140-280/month savings
**Effort**: 5 minutes

- Change maximum hosts from 3 to 2
- Peak demand (13) easily handled by 2 hosts

#### 7.4 Audit Shared Accounts
**Impact**: Licensing compliance
**Effort**: 1 hour

- Review 5 shared/service accounts
- Determine if individual accounts needed
- Consult Microsoft licensing guidance

### Priority 3: Optimization (This Quarter)

#### 7.5 Implement Scheduled Scaling
- Configure business hours scaling plan
- Reduce to 1 host minimum off-peak
- Zero hosts on weekends (if acceptable)

#### 7.6 Review Light Users
- 3 users with minimal activity
- Determine if AVD access still needed
- Potential license consolidation

---

## 8. Implementation Roadmap

### Week 1: Immediate Wins

| Day | Action | Owner | Outcome |
|-----|--------|-------|---------|
| 1 | Review current autoscaling config | IT Admin | Baseline documented |
| 1 | Investigate AZHOST-2 idle hours | IT Admin | Root cause identified |
| 2 | Update autoscaling settings | IT Admin | Min hosts = 1 |
| 3-5 | Monitor for impact | IT Admin | Validate no user issues |

### Week 2: Optimization

| Day | Action | Owner | Outcome |
|-----|--------|-------|---------|
| 1 | Reduce max hosts to 2 | IT Admin | Capacity right-sized |
| 2-3 | Monitor peak hours | IT Admin | Validate capacity sufficient |
| 4 | Configure scheduled scaling | IT Admin | Business hours automation |
| 5 | Document new baseline | IT Admin | Updated runbook |

### Week 3-4: Compliance & Monitoring

| Day | Action | Owner | Outcome |
|-----|--------|-------|---------|
| 1-2 | Audit shared accounts | IT Admin + Licensing | Compliance review |
| 3 | Review light user access | IT Admin + Managers | Access validation |
| 4-5 | Implement AVD Insights workbook | IT Admin | Ongoing monitoring |

---

## Appendix A: KQL Queries Used

### Query 1: Session Host Utilization
```kusto
WVDConnections
| where TimeGenerated > ago(30d)
| where State == "Connected"
| summarize
    ConcurrentSessions = dcount(CorrelationId),
    TotalConnections = count()
    by SessionHostName, bin(TimeGenerated, 1h)
| summarize
    AvgConcurrentSessions = avg(ConcurrentSessions),
    MaxConcurrentSessions = max(ConcurrentSessions),
    MinConcurrentSessions = min(ConcurrentSessions)
    by SessionHostName
| order by AvgConcurrentSessions asc
```

### Query 2: Peak Usage Hours
```kusto
WVDConnections
| where TimeGenerated > ago(30d)
| where State == "Connected"
| extend HourOfDay = datetime_part("hour", TimeGenerated)
| extend DayOfWeek = dayofweek(TimeGenerated)
| summarize SessionCount = dcount(CorrelationId) by HourOfDay, DayOfWeek
| order by DayOfWeek asc, HourOfDay asc
```

### Query 3: Empty Host Hours
```kusto
let ActiveHosts = WVDAgentHealthStatus
| where TimeGenerated > ago(30d)
| where Status == "Available"
| summarize by SessionHostName, bin(TimeGenerated, 1h);
let HostsWithSessions = WVDConnections
| where TimeGenerated > ago(30d)
| where State == "Connected"
| summarize by SessionHostName, bin(TimeGenerated, 1h);
ActiveHosts
| join kind=leftanti HostsWithSessions on SessionHostName, TimeGenerated
| summarize EmptyHours = count() by SessionHostName
| order by EmptyHours desc
```

### Query 4: User Activity
```kusto
WVDConnections
| where TimeGenerated > ago(30d)
| where State == "Connected"
| summarize
    TotalSessions = count(),
    UniqueDays = dcount(bin(TimeGenerated, 1d)),
    AvgSessionsPerDay = count() / 30.0
    by UserName
| order by TotalSessions desc
| take 50
```

### Query 5: Host Pool Capacity
```kusto
WVDConnections
| where TimeGenerated > ago(30d)
| where State == "Connected"
| summarize ActiveSessions = dcount(CorrelationId) by bin(TimeGenerated, 1h), HostPoolName
| summarize
    AvgActiveSessions = avg(ActiveSessions),
    PeakSessions = max(ActiveSessions),
    P95Sessions = percentile(ActiveSessions, 95)
    by HostPoolName
```

---

## Appendix B: Cost Reference (Australia East)

| VM Size | vCPU | RAM | Pay-As-You-Go/hr | Monthly (24/7) | Users/Host |
|---------|------|-----|------------------|----------------|------------|
| D2s_v5 | 2 | 8 GB | $0.096 | $70 | 4-6 |
| D4s_v5 | 4 | 16 GB | $0.192 | $140 | 8-12 |
| D8s_v5 | 8 | 32 GB | $0.384 | $280 | 16-24 |
| D16s_v5 | 16 | 64 GB | $0.768 | $560 | 32-48 |

---

**Report Completed**: January 2026
**Next Review**: February 2026
**Contact**: Azure Architect Agent
