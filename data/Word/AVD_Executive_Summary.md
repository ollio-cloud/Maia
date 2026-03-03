# Azure Virtual Desktop Utilization Report
## Executive Summary | SSGroup | January 2026

---

## Key Metrics (30-Day Analysis)

| Metric | Value | Status |
|--------|-------|--------|
| **Total Users** | 26 | Small environment |
| **Session Hosts** | 3 | Over-provisioned |
| **Average Concurrent Sessions** | 2.86 | Low utilization |
| **95th Percentile (P95)** | 7 | 1 host sufficient 95% of time |
| **Peak Concurrent** | 13 | 2 hosts sufficient |
| **Empty Host Hours** | 603 (28%) | Waste identified |

---

## Financial Impact

### Current State
- **Estimated Monthly Cost**: $420-840 (depending on VM size)
- **Wasted Compute**: 603 hours/month (hosts running with zero users)
- **Waste Cost**: $115-229/month

### Optimization Opportunity

| Action | Monthly Savings | Annual Savings |
|--------|-----------------|----------------|
| Fix autoscaling configuration | $100-200 | $1,200-2,400 |
| Reduce maximum hosts (3→2) | $140-280 | $1,680-3,360 |
| **Total Potential Savings** | **$240-480** | **$2,880-5,760** |

---

## Recommendations

### Immediate Actions (This Week)
1. **Fix Autoscaling** - Reduce minimum hosts to 1, decrease ramp-down wait time
2. **Investigate AZHOST-2** - 404 empty hours (56% idle) indicates configuration issue

### Short-Term (This Month)
3. **Reduce Host Pool Maximum** - Change from 3 to 2 hosts (peak demand is only 13)
4. **Review Shared Accounts** - 5 shared/service accounts detected (licensing compliance)

### Monitoring (Ongoing)
5. **Implement AVD Insights Dashboard** - Track utilization trends monthly

---

## Usage Pattern Summary

```
Peak Usage Window:  06:00 - 17:00 AEST (Business Hours)
Off-Peak:           17:00 - 06:00 AEST (Minimal Usage)
Weekend:            Near-zero usage
```

**Conclusion**: Environment is correctly sized for peak demand but significantly over-provisioned during off-peak hours. Autoscaling optimization will reduce costs by 30-50% with no impact on user experience.

---

**Report Generated**: January 2026
**Environment**: ssg-avd-pool-001
**Analysis Period**: 30 days
**Prepared by**: Azure Architect Agent

---

*For detailed technical findings and implementation steps, refer to the Technical Report and Autoscaling Configuration Guide.*
