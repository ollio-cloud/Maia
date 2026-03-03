# Change Request: Intune Connector Upgrade

## Change Details

| Field | Value |
|-------|-------|
| Change ID | CR-XXXX |
| Change Title | Microsoft Intune Connector Upgrade |
| Requested By | |
| Date Submitted | |
| Target Implementation Date | |
| Change Type | Standard |
| Priority | Medium |
| Risk Level | Low-Medium |

---

## 1. Change Description

Upgrade the Microsoft Intune Connector to the latest version to ensure continued compatibility, security updates, and feature support.

### Scope
- Intune Connector service upgrade on designated server(s)
- Validation of connector functionality post-upgrade

### Affected Systems
| System | Role |
|--------|------|
| [Server Name] | Intune Connector Host |
| Microsoft Intune | Cloud Service |
| Active Directory | Identity Source |

---

## 2. Implementation Plan

### 2.1 Pre-Implementation Tasks

| Step | Action | Owner | Duration |
|------|--------|-------|----------|
| 1 | Notify stakeholders of scheduled maintenance window | | |
| 2 | Confirm backup of connector server is current | | 15 min |
| 3 | Document current connector version | | 5 min |
| 4 | Download latest Intune Connector installer from Microsoft | | 10 min |
| 5 | Review Microsoft release notes for breaking changes | | 15 min |
| 6 | Verify admin credentials and access to server | | 5 min |

### 2.2 Implementation Steps

| Step | Action | Owner | Duration |
|------|--------|-------|----------|
| 1 | Log into connector server with administrative credentials | | 2 min |
| 2 | Open Services console and stop the Intune Connector service | | 2 min |
| 3 | Create system restore point | | 5 min |
| 4 | Run the Intune Connector installer | | 10 min |
| 5 | Follow installation wizard prompts, accepting defaults unless otherwise specified | | 5 min |
| 6 | Re-authenticate connector with Intune tenant if prompted | | 5 min |
| 7 | Start the Intune Connector service if not started automatically | | 2 min |
| 8 | Verify service is running and set to Automatic startup | | 2 min |

**Estimated Total Implementation Time:** 30-45 minutes

### 2.3 Post-Implementation Tasks

| Step | Action | Owner | Duration |
|------|--------|-------|----------|
| 1 | Execute verification plan (see Section 4) | | 20 min |
| 2 | Monitor connector logs for errors | | 15 min |
| 3 | Update CMDB with new version number | | 5 min |
| 4 | Close change request with implementation notes | | 5 min |

---

## 3. Rollback Plan

### 3.1 Rollback Triggers
Initiate rollback if any of the following occur:
- Connector service fails to start after upgrade
- Authentication to Intune tenant fails
- Device enrollment/sync functionality is broken
- Critical errors in event logs preventing normal operation

### 3.2 Rollback Steps

| Step | Action | Owner | Duration |
|------|--------|-------|----------|
| 1 | Stop the Intune Connector service | | 2 min |
| 2 | Open Programs and Features (appwiz.cpl) | | 1 min |
| 3 | Uninstall the current Intune Connector version | | 5 min |
| 4 | Restore from system restore point if uninstall fails | | 15 min |
| 5 | Reinstall previous connector version from retained installer | | 10 min |
| 6 | Re-authenticate with Intune tenant | | 5 min |
| 7 | Verify service starts and functions correctly | | 5 min |
| 8 | Execute verification plan to confirm rollback success | | 20 min |

**Estimated Rollback Time:** 45-60 minutes

### 3.3 Rollback Decision Authority
| Role | Authority |
|------|-----------|
| Change Implementer | Can initiate rollback for technical failures |
| Change Manager | Must approve rollback for business reasons |

---

## 4. Verification Plan

### 4.1 Service Verification

| Check | Expected Result | Pass/Fail |
|-------|-----------------|-----------|
| Intune Connector service is running | Status: Running | ☐ |
| Service startup type is Automatic | Startup: Automatic | ☐ |
| No errors in Windows Event Log (Application) | No critical/error events | ☐ |
| Connector version matches target version | Version: [Target Version] | ☐ |

### 4.2 Connectivity Verification

| Check | Expected Result | Pass/Fail |
|-------|-----------------|-----------|
| Connector appears healthy in Intune Admin Center | Status: Active/Healthy | ☐ |
| Last sync time is recent (within 15 minutes) | Timestamp updated | ☐ |
| No connectivity errors in connector logs | No connection failures | ☐ |

### 4.3 Functional Verification

| Check | Expected Result | Pass/Fail |
|-------|-----------------|-----------|
| Test device enrollment (if applicable) | Enrollment successful | ☐ |
| Policy sync to test device | Policies applied | ☐ |
| Certificate issuance (if SCEP/PKCS configured) | Certificate issued | ☐ |
| Compliance status updates | Status reflects current state | ☐ |

### 4.4 Verification Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Implementer | | | |
| Technical Approver | | | |

---

## 5. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Service fails to start post-upgrade | Low | High | System restore point; rollback plan |
| Compatibility issues with current environment | Low | Medium | Review release notes; test in non-prod if available |
| Authentication issues with Intune tenant | Low | High | Verify credentials before change; have Global Admin available |
| Extended downtime beyond maintenance window | Low | Medium | Communicate buffer time; have rollback ready |

---

## 6. Communication Plan

| When | Who | What |
|------|-----|------|
| 5 business days before | Stakeholders, IT Team | Scheduled maintenance notification |
| Day of implementation | IT Team | Implementation start notification |
| Post-implementation | Stakeholders, IT Team | Completion confirmation and status |
| If rollback required | Stakeholders, Management | Rollback notification and next steps |

---

## 7. Approvals

| Role | Name | Date | Approval |
|------|------|------|----------|
| Change Requester | | | |
| Technical Reviewer | | | |
| Change Manager | | | |
| CAB (if required) | | | |

---

## 8. Implementation Notes

*To be completed during/after implementation:*

| Field | Details |
|-------|---------|
| Actual Start Time | |
| Actual End Time | |
| Previous Version | |
| New Version | |
| Issues Encountered | |
| Rollback Required | Yes / No |
| Verification Complete | Yes / No |

---

*Document Version: 1.0*
*Last Updated: [Date]*
