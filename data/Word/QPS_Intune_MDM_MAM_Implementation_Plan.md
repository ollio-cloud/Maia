# QPS Intune MDM and MAM Implementation Plan
**Project**: 3596263 - QPS - Intune MDM and MAM
**Program Manager**: George Alex
**Author**: Olli Ojala (Cloud Project Engineer)
**Created**: 2025-08-22
**Status**: Phase 0 - Planning Complete, Implementation Ready
**Priority**: High - Security and Compliance Critical

---

## 🚨 **RESUMPTION PROTOCOL** 🚨
**IF YOU ARE RETURNING TO THIS PROJECT:**

1. **Check Current Status**: Review the Implementation Status Dashboard below
2. **Load Next Task**: Find your current phase and next uncompleted task
3. **Resume Implementation**: Follow the specific phase steps indicated
4. **Update Progress**: Mark tasks complete as you finish them

**CRITICAL FILES FOR RESUMPTION:**
- This file: Overall plan and status
- Detailed design document: `QPS - Intune MDM and MAM implementation detailed design.docx`
- Intune Admin Portal: https://intune.microsoft.com
- Entra Admin Portal: https://entra.microsoft.com

---

## Project Overview

### Objective
Enable secure, compliant, and seamless access to corporate resources from both personal (BYOD) and QPS-managed mobile devices, while maintaining strict data protection controls and minimizing risk to the enterprise environment.

### Solution Architecture
The solution leverages:
1. **Microsoft Endpoint Manager (Intune)** - Device and application management
2. **Microsoft Entra ID Conditional Access** - Adaptive access controls
3. **Microsoft Defender for Cloud Apps** - Cloud application governance

### Design Principles
- Ensure corporate data remains secure and compliant when accessed from mobile devices
- Support hybrid device environment (QPS-owned iOS/Android + BYOD iOS/Android/Windows/macOS)
- Enforce consistent security controls through Zero Trust principles
- Balance user experience with organizational security needs

### Success Metrics
| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Policy Deployment Success | 100% | Intune compliance reports |
| User Enrollment Success | >95% | Enrollment analytics |
| Conditional Access Enforcement | 100% | CA sign-in logs |
| Data Protection Compliance | 100% | MAM policy reports |
| Helpdesk Ticket Reduction | 30% post go-live | ServiceNow metrics |

---

## Implementation Phases

### Phase 0: Planning & Prerequisites ✅ **COMPLETE**
**Status**: Complete
**Duration**: 1 week
**Deliverables**:
- ✅ Detailed design document created
- ✅ Implementation plan created (this document)
- ✅ Success metrics defined
- ✅ Business requirements documented

---

### Phase 1: Foundation Setup
**Status**: Ready to Start
**Duration**: 1 week
**Priority**: Critical - Foundation for all policy deployment
**Prerequisites**: Intune licenses assigned, Entra ID Premium P1/P2

#### Task 1.1: Verify Tenant Configuration
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Steps**:
- [ ] Verify Microsoft Intune license assignment for pilot users
- [ ] Verify Entra ID Premium P1/P2 license assignment
- [ ] Confirm Apple Business Manager (ABM) integration
- [ ] Verify Android Enterprise binding
- [ ] Document current tenant configuration state

**Validation**:
- [ ] All pilot users have required licenses
- [ ] ABM sync working correctly
- [ ] Android Enterprise enrollment profile accessible

#### Task 1.2: Create Assignment Groups
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Groups to Create**:
| Group Name | Type | Purpose |
|------------|------|---------|
| QPS-Intune-Pilot-Users | Security | Pilot phase testing |
| QPS-MDM-iOS-Devices | Dynamic Device | Corporate iOS devices |
| QPS-MDM-Android-Devices | Dynamic Device | Corporate Android devices |
| QPS-MAM-BYOD-Users | Security | BYOD MAM policy targeting |
| QPS-MAM-Exclude | Security | MAM policy exclusions |
| QPS-CA-Exclude | Security | Conditional Access exclusions |

**Steps**:
- [ ] Create all security groups in Entra ID
- [ ] Configure dynamic membership rules for device groups
- [ ] Add pilot users to QPS-Intune-Pilot-Users
- [ ] Add break-glass accounts to exclusion groups
- [ ] Document group membership criteria

**Validation**:
- [ ] All groups created and accessible
- [ ] Dynamic rules populating correctly
- [ ] Break-glass accounts protected from lockout

#### Task 1.3: Create Device Filters
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Filters to Create**:
| Filter Name | Platform | Purpose |
|-------------|----------|---------|
| Orro - QPS - Android Corporate Owned Devices | Android | Target corporate Android MDM policies |
| Orro - QPS - iOS Corporate Owned Devices | iOS | Target corporate iOS MDM policies |

**Steps**:
- [ ] Create Android corporate device filter using deviceOwnership property
- [ ] Create iOS corporate device filter using deviceOwnership property
- [ ] Test filter logic with sample queries
- [ ] Document filter syntax and purpose

**Validation**:
- [ ] Filters return expected device counts
- [ ] Filter syntax validated without errors

---

### Phase 2: Intune MAM Policy Deployment
**Status**: Pending Phase 1 Completion
**Duration**: 1.5 weeks
**Priority**: High - BYOD protection foundation
**Prerequisites**: Phase 1 complete, pilot users identified

#### Task 2.1: Deploy Android MAM Policy
**Owner**: Olli Ojala
**Status**: ⬜ Not Started
**Policy Name**: Orro - QPS - Android App Protection Policy

**Policy Configuration**:
| Setting | Value |
|---------|-------|
| Target Apps | Microsoft Core Apps (Outlook, Teams, OneDrive, SharePoint, Edge) |
| Data Transfer | Block cut/copy/paste to unmanaged apps |
| Encryption | Require |
| Access PIN | 4+ digits minimum |
| Biometrics | Allowed |
| Jailbreak Detection | Block access |
| Min OS Version | Define based on QPS requirements |
| Offline Grace Period | 720 minutes (12 hours) |
| Wipe after offline days | 90 days |

**Steps**:
- [ ] Create Android App Protection Policy in Intune
- [ ] Configure data protection settings (encryption, copy/paste restrictions)
- [ ] Configure access requirements (PIN, biometrics)
- [ ] Configure conditional launch (jailbreak detection, min OS)
- [ ] Configure health checks (offline grace period, selective wipe timer)
- [ ] Assign to QPS-Intune-Pilot-Users group
- [ ] Exclude QPS-MAM-Exclude group
- [ ] Document all configured settings

**Validation**:
- [ ] Policy shows as assigned in Intune portal
- [ ] Pilot user receives policy on Android BYOD device
- [ ] Copy/paste restriction working between managed and unmanaged apps
- [ ] PIN prompt appears when accessing managed apps
- [ ] Jailbreak detection blocks rooted test device (if available)

#### Task 2.2: Deploy iOS MAM Policy
**Owner**: Olli Ojala
**Status**: ⬜ Not Started
**Policy Name**: Orro - QPS - iOS App Protection Policy

**Policy Configuration**:
| Setting | Value |
|---------|-------|
| Target Apps | Microsoft Core Apps (Outlook, Teams, OneDrive, SharePoint, Edge) |
| Data Transfer | Block cut/copy/paste to unmanaged apps |
| Encryption | Require |
| Access PIN | 4+ digits minimum |
| Biometrics | Allowed (Face ID/Touch ID) |
| Jailbreak Detection | Block access |
| Min OS Version | Define based on QPS requirements |
| Offline Grace Period | 720 minutes (12 hours) |
| Wipe after offline days | 90 days |

**Steps**:
- [ ] Create iOS App Protection Policy in Intune
- [ ] Configure data protection settings (encryption, copy/paste restrictions)
- [ ] Configure access requirements (PIN, biometrics)
- [ ] Configure conditional launch (jailbreak detection, min OS)
- [ ] Configure health checks (offline grace period, selective wipe timer)
- [ ] Assign to QPS-Intune-Pilot-Users group
- [ ] Exclude QPS-MAM-Exclude group
- [ ] Document all configured settings

**Validation**:
- [ ] Policy shows as assigned in Intune portal
- [ ] Pilot user receives policy on iOS BYOD device
- [ ] Copy/paste restriction working between managed and unmanaged apps
- [ ] PIN/Face ID/Touch ID prompt appears when accessing managed apps
- [ ] Jailbreak detection blocks jailbroken test device (if available)

#### Task 2.3: Deploy Windows MAM Policy (If Required)
**Owner**: Olli Ojala
**Status**: ⬜ Not Started
**Policy Name**: Orro - QPS - Windows App Protection Policy
**Note**: Per detailed design, this policy is currently NOT in use

**Policy Configuration**:
| Setting | Value |
|---------|-------|
| Target Apps | Microsoft Edge browser |
| Data Transfer | Block downloads, block send outside browser, block cut/copy/paste |
| Printing | Allowed |
| Scope | Microsoft Office applications within browser only |

**Steps**:
- [ ] Confirm with stakeholders if Windows MAM policy is required
- [ ] If yes, create Windows App Protection Policy targeting Edge
- [ ] Configure browser-based data protection settings
- [ ] Assign to appropriate user group
- [ ] Document all configured settings

**Validation**:
- [ ] Policy enforcement in Edge browser on BYOD Windows device
- [ ] Downloads blocked for corporate content
- [ ] Copy/paste restricted for M365 web apps
- [ ] Printing allowed

---

### Phase 3: Intune MDM Policy Deployment
**Status**: Pending Phase 2 Completion
**Duration**: 1.5 weeks
**Priority**: High - Corporate device management
**Prerequisites**: Phase 2 complete, test devices available

#### Task 3.1: Configure iOS Enrollment Profiles
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Profiles to Create**:
| Profile Name | Type | Use Case |
|--------------|------|----------|
| Orro - iOS Without User Affinity Profile | DEP | Shared devices, kiosks |
| Orro - iOS User Affinity Profile | DEP | Personal corporate devices |

**Steps**:
- [ ] Create enrollment profile without user affinity in ABM
- [ ] Create enrollment profile with user affinity in ABM
- [ ] Configure enrollment settings (supervision, department info)
- [ ] Assign tokens/devices to appropriate profiles
- [ ] Document profile configurations

**Validation**:
- [ ] Profiles appear in Intune as synced from ABM
- [ ] Test device enrollment with each profile type
- [ ] User affinity correctly associates device to user

#### Task 3.2: Deploy iOS Compliance Policy
**Owner**: Olli Ojala
**Status**: ⬜ Not Started
**Policy Name**: Orro - iOS compliance policy

**Policy Configuration**:
| Setting | Value |
|---------|-------|
| Jailbreak | Block |
| Minimum OS Version | Define per QPS requirements |
| Maximum OS Version | None (allow latest) |
| Password Required | Yes |
| Simple Password | Block |
| Minimum Password Length | 6 characters |
| Device Encryption | Required |
| Non-compliance Action | Mark non-compliant immediately |
| Grace Period | Define per QPS requirements |

**Steps**:
- [ ] Create iOS compliance policy
- [ ] Configure device health settings (jailbreak detection)
- [ ] Configure OS version requirements
- [ ] Configure password requirements
- [ ] Configure actions for non-compliance
- [ ] Assign to QPS-MDM-iOS-Devices group
- [ ] Document all settings

**Validation**:
- [ ] Compliance policy applied to enrolled iOS device
- [ ] Device correctly reports compliance status
- [ ] Non-compliant device marked correctly

#### Task 3.3: Deploy iOS Configuration Profile
**Owner**: Olli Ojala
**Status**: ⬜ Not Started
**Policy Name**: Orro - iOS Supervised Enhanced Security Configuration

**Configuration Categories**:
- Device restrictions
- Wi-Fi profiles
- VPN profiles (if required)
- Email profiles
- Certificate profiles

**Steps**:
- [ ] Create configuration profile with device restrictions
- [ ] Configure security baseline settings (AirDrop restrictions, backup to iCloud, etc.)
- [ ] Configure Wi-Fi profile for corporate network
- [ ] Configure email profile if required
- [ ] Assign to QPS-MDM-iOS-Devices group
- [ ] Document all settings

**Validation**:
- [ ] Configuration profile applied to enrolled device
- [ ] Restrictions enforced correctly
- [ ] Wi-Fi auto-connects to corporate network

#### Task 3.4: Configure Android Enrollment Profile
**Owner**: Olli Ojala
**Status**: ⬜ Not Started
**Profile Name**: Orro - Android - Corporate Owned Fully Managed Enrollment Profile

**Steps**:
- [ ] Create Android Enterprise fully managed enrollment profile
- [ ] Generate QR code for device provisioning
- [ ] Configure enrollment settings (system apps, network requirements)
- [ ] Test enrollment with sample device
- [ ] Document enrollment process and QR code location

**Validation**:
- [ ] QR code generates successfully
- [ ] Device enrolls via QR code scan
- [ ] Device shows as corporate-owned fully managed

#### Task 3.5: Deploy Android Compliance Policy
**Owner**: Olli Ojala
**Status**: ⬜ Not Started
**Policy Name**: Orro - Android Fully managed enhanced security compliance

**Policy Configuration**:
| Setting | Value |
|---------|-------|
| Root Detection | Block |
| Minimum OS Version | Define per QPS requirements |
| SafetyNet Device Attestation | Basic integrity |
| Password Required | Yes |
| Minimum Password Length | 6 characters |
| Device Encryption | Required |
| Google Play Services | Required |
| Non-compliance Action | Mark non-compliant immediately |

**Steps**:
- [ ] Create Android compliance policy
- [ ] Configure device health settings (root detection, SafetyNet)
- [ ] Configure OS version requirements
- [ ] Configure password requirements
- [ ] Configure actions for non-compliance
- [ ] Assign to QPS-MDM-Android-Devices group
- [ ] Document all settings

**Validation**:
- [ ] Compliance policy applied to enrolled Android device
- [ ] Device correctly reports compliance status
- [ ] SafetyNet attestation passes

#### Task 3.6: Deploy Android Configuration Profile
**Owner**: Olli Ojala
**Status**: ⬜ Not Started
**Policy Name**: Orro - Android Fully Managed Enhanced Security Configuration

**Steps**:
- [ ] Create configuration profile with device restrictions
- [ ] Configure security baseline settings
- [ ] Configure Wi-Fi profile for corporate network
- [ ] Configure work profile settings (if applicable)
- [ ] Assign to QPS-MDM-Android-Devices group
- [ ] Document all settings

**Validation**:
- [ ] Configuration profile applied to enrolled device
- [ ] Restrictions enforced correctly
- [ ] Wi-Fi auto-connects to corporate network

---

### Phase 4: Conditional Access Policy Deployment
**Status**: Pending Phase 3 Completion
**Duration**: 1 week
**Priority**: Critical - Access enforcement
**Prerequisites**: Phase 3 complete, MAM and MDM policies validated

#### Task 4.1: Deploy BYOD Web Access Policy
**Owner**: Olli Ojala
**Status**: ⬜ Not Started
**Policy Name**: Orro – BYOD Allow Web Access

**Policy Configuration**:
| Setting | Value |
|---------|-------|
| Target Resources | Office 365 |
| Device Platforms | Windows, macOS |
| Client Apps | Browser |
| Device Filter | Exclude: trustType Equals Microsoft Entra Joined or Microsoft Entra Hybrid Joined |
| Grant | Require app protection policy |

**Steps**:
- [ ] Create Conditional Access policy in Entra ID
- [ ] Configure target resources (Office 365)
- [ ] Configure conditions (Windows, macOS, Browser only)
- [ ] Configure device filter to exclude corporate devices
- [ ] Configure grant control (require app protection policy)
- [ ] Assign to QPS-Intune-Pilot-Users initially
- [ ] Add QPS-CA-Exclude to exclusions
- [ ] Enable policy in Report-only mode first
- [ ] Document all settings

**Validation**:
- [ ] Report-only mode shows expected sign-in results
- [ ] BYOD Windows/Mac users can access M365 via browser with MAM
- [ ] Corporate joined devices excluded from policy

#### Task 4.2: Deploy BYOD Desktop Client Block Policy
**Owner**: Olli Ojala
**Status**: ⬜ Not Started
**Policy Name**: Orro – BYOD Block Desktop Clients

**Policy Configuration**:
| Setting | Value |
|---------|-------|
| Target Resources | Office 365 |
| Device Platforms | Windows, macOS |
| Client Apps | Mobile apps and desktop clients |
| Device Filter | Exclude: isCompliant Equals True |
| Grant | Block access |

**Steps**:
- [ ] Create Conditional Access policy
- [ ] Configure target resources (Office 365)
- [ ] Configure conditions (Windows, macOS, Desktop clients)
- [ ] Configure device filter to exclude compliant devices
- [ ] Configure grant control (Block access)
- [ ] Assign to QPS-Intune-Pilot-Users initially
- [ ] Add QPS-CA-Exclude to exclusions
- [ ] Enable in Report-only mode first
- [ ] Document all settings

**Validation**:
- [ ] Report-only mode shows expected blocks
- [ ] BYOD Windows/Mac desktop apps blocked
- [ ] Compliant corporate devices excluded

#### Task 4.3: Deploy MAM Enforce Policy (iOS/Android)
**Owner**: Olli Ojala
**Status**: ⬜ Not Started
**Policy Name**: Orro – MAM Policy enforce iOS and Android

**Policy Configuration**:
| Setting | Value |
|---------|-------|
| Target Resources | Office 365 |
| Device Platforms | Android, iOS |
| Client Apps | Browser, Mobile apps and desktop clients |
| Device Filter | Exclude: deviceOwnership Equals Company |
| Grant | Require app protection policy |

**Steps**:
- [ ] Create Conditional Access policy
- [ ] Configure target resources (Office 365)
- [ ] Configure conditions (iOS, Android, All client apps)
- [ ] Configure device filter to exclude corporate-owned devices
- [ ] Configure grant control (require app protection policy)
- [ ] Assign to QPS-Intune-Pilot-Users initially
- [ ] Add QPS-CA-Exclude to exclusions
- [ ] Enable in Report-only mode first
- [ ] Document all settings

**Validation**:
- [ ] Report-only mode shows expected results
- [ ] BYOD iOS/Android requires MAM-protected apps
- [ ] Corporate devices excluded from policy

#### Task 4.4: Deploy MCAS Session Control Policy
**Owner**: Olli Ojala
**Status**: ⬜ Not Started
**Policy Name**: Orro – BYOD macOS/Windows Block download/copy/cut/paste – Office 365 browser (MCAS)

**Policy Configuration**:
| Setting | Value |
|---------|-------|
| Target Resources | Office 365 |
| Device Platforms | macOS, Windows |
| Client Apps | Browser |
| Device Filter | Exclude: deviceOwnership Equals Company OR trustType Equals Microsoft Entra Joined or Hybrid Joined |
| Session | Use Conditional Access App Control – Use Custom Policy |

**Steps**:
- [ ] Create Conditional Access policy
- [ ] Configure target resources (Office 365)
- [ ] Configure conditions (Windows, macOS, Browser)
- [ ] Configure device filter for BYOD targeting
- [ ] Configure session control (Use Conditional Access App Control)
- [ ] Select "Use Custom Policy" option
- [ ] Assign to QPS-Intune-Pilot-Users initially
- [ ] Add QPS-CA-Exclude to exclusions
- [ ] Enable in Report-only mode first
- [ ] Document all settings

**Validation**:
- [ ] MCAS portal shows session traffic from BYOD browser sessions
- [ ] Policy routes sessions through MCAS proxy
- [ ] Corporate devices excluded

---

### Phase 5: Microsoft Defender for Cloud Apps Configuration
**Status**: Pending Phase 4 Completion
**Duration**: 1 week
**Priority**: High - Data loss prevention
**Prerequisites**: Phase 4 complete, MCAS CA policy active

#### Task 5.1: Configure Block Copy/Cut/Paste Policy
**Owner**: Olli Ojala
**Status**: ⬜ Not Started
**Template**: Block cut/copy and paste based on real-time content inspection

**Target Applications**:
- Microsoft Online Services (Exchange Online, SharePoint Online, OneDrive)
- Teams
- Power Platform apps

**Steps**:
- [ ] Navigate to Microsoft Defender for Cloud Apps portal
- [ ] Create session policy from template
- [ ] Configure activity filters (cut, copy, paste actions)
- [ ] Configure app filters (target M365 apps)
- [ ] Configure device filter (BYOD only via CA integration)
- [ ] Set action to Block
- [ ] Configure user notification message
- [ ] Enable policy
- [ ] Document all settings

**Validation**:
- [ ] Policy appears in MCAS policies list
- [ ] Cut/copy/paste blocked in browser session for BYOD user
- [ ] User receives notification message
- [ ] Action logged in MCAS activity log

#### Task 5.2: Configure Block Download Policy
**Owner**: Olli Ojala
**Status**: ⬜ Not Started
**Template**: Block download based on real-time content inspection

**Target Applications**:
- Microsoft Online Services (Exchange Online, SharePoint Online, OneDrive)
- Teams

**Steps**:
- [ ] Create session policy from template
- [ ] Configure activity filters (file download)
- [ ] Configure app filters (target M365 apps)
- [ ] Configure device filter (BYOD only via CA integration)
- [ ] Configure content inspection settings (if applicable)
- [ ] Set action to Block
- [ ] Configure user notification message
- [ ] Enable policy
- [ ] Document all settings

**Validation**:
- [ ] Policy appears in MCAS policies list
- [ ] File downloads blocked in browser session for BYOD user
- [ ] User receives notification message
- [ ] Action logged in MCAS activity log

---

### Phase 6: Pilot Testing
**Status**: Pending Phase 5 Completion
**Duration**: 2 weeks
**Priority**: Critical - Validation before production
**Prerequisites**: All policies deployed, pilot users identified

#### Task 6.1: Pilot User Communication
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Steps**:
- [ ] Draft pilot communication email
- [ ] Create user guide for BYOD enrollment (iOS)
- [ ] Create user guide for BYOD enrollment (Android)
- [ ] Create FAQ document
- [ ] Schedule pilot kickoff meeting
- [ ] Send communications to pilot users
- [ ] Document support contact info

#### Task 6.2: BYOD MAM Testing (iOS)
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Test Cases**:
| Test Case | Expected Result | Status |
|-----------|-----------------|--------|
| Install Outlook on personal iOS | Prompts for MAM enrollment | ⬜ |
| Set MAM PIN | 4+ digit PIN accepted | ⬜ |
| Configure Face ID/Touch ID | Biometric accepted | ⬜ |
| Copy text from Outlook | Cannot paste in personal app | ⬜ |
| Access from jailbroken device | Access blocked | ⬜ |
| Offline access (12+ hours) | Requires reauthentication | ⬜ |
| Selective wipe execution | Corporate data removed, personal data intact | ⬜ |

#### Task 6.3: BYOD MAM Testing (Android)
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Test Cases**:
| Test Case | Expected Result | Status |
|-----------|-----------------|--------|
| Install Outlook on personal Android | Prompts for MAM enrollment | ⬜ |
| Set MAM PIN | 4+ digit PIN accepted | ⬜ |
| Configure fingerprint | Biometric accepted | ⬜ |
| Copy text from Teams | Cannot paste in personal app | ⬜ |
| Access from rooted device | Access blocked | ⬜ |
| Offline access (12+ hours) | Requires reauthentication | ⬜ |
| Selective wipe execution | Corporate data removed, personal data intact | ⬜ |

#### Task 6.4: Corporate MDM Testing (iOS)
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Test Cases**:
| Test Case | Expected Result | Status |
|-----------|-----------------|--------|
| Enroll via ABM/DEP | Device enrolls supervised | ⬜ |
| Compliance check passes | Device marked compliant | ⬜ |
| Configuration profile applied | Restrictions enforced | ⬜ |
| Wi-Fi auto-connect | Connects to corporate network | ⬜ |
| Non-compliant scenario | Marked non-compliant, access blocked | ⬜ |
| Remote wipe (test device) | Device factory reset | ⬜ |
| Remote lock | Device locked | ⬜ |

#### Task 6.5: Corporate MDM Testing (Android)
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Test Cases**:
| Test Case | Expected Result | Status |
|-----------|-----------------|--------|
| Enroll via QR code | Device enrolls as fully managed | ⬜ |
| Compliance check passes | Device marked compliant | ⬜ |
| Configuration profile applied | Restrictions enforced | ⬜ |
| Wi-Fi auto-connect | Connects to corporate network | ⬜ |
| Non-compliant scenario | Marked non-compliant, access blocked | ⬜ |
| Remote wipe (test device) | Device factory reset | ⬜ |
| Remote lock | Device locked | ⬜ |

#### Task 6.6: Conditional Access Testing
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Test Cases**:
| Test Case | Expected Result | Status |
|-----------|-----------------|--------|
| BYOD Windows browser access | Allowed with MAM | ⬜ |
| BYOD Windows desktop app | Blocked | ⬜ |
| BYOD macOS browser access | Allowed with MAM | ⬜ |
| BYOD macOS desktop app | Blocked | ⬜ |
| Corporate Windows access | Allowed (compliant) | ⬜ |
| BYOD iOS/Android M365 app | Requires MAM policy | ⬜ |
| MCAS session - copy/paste | Blocked for BYOD | ⬜ |
| MCAS session - download | Blocked for BYOD | ⬜ |

#### Task 6.7: Pilot Feedback Collection
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Steps**:
- [ ] Create feedback survey
- [ ] Distribute survey to pilot users
- [ ] Conduct 1:1 interviews with key users
- [ ] Document all feedback
- [ ] Categorize issues (bugs, UX, policy tuning)
- [ ] Create remediation plan for critical issues

---

### Phase 7: Production Rollout
**Status**: Pending Phase 6 Completion
**Duration**: 2-3 weeks
**Priority**: High - Final deployment
**Prerequisites**: Pilot complete, no critical issues

#### Task 7.1: Move Policies to Report-Only → Enabled
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Steps**:
- [ ] Review all CA policies currently in Report-only mode
- [ ] Verify no unexpected blocks in sign-in logs
- [ ] Enable Orro – BYOD Allow Web Access
- [ ] Enable Orro – BYOD Block Desktop Clients
- [ ] Enable Orro – MAM Policy enforce iOS and Android
- [ ] Enable Orro – BYOD macOS/Windows MCAS session control
- [ ] Monitor sign-in logs for 24-48 hours
- [ ] Document any issues

#### Task 7.2: Expand User Assignment
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Steps**:
- [ ] Plan rollout waves (by department/location)
- [ ] Update MAM policy assignments from pilot to All Users (with exclusions)
- [ ] Update CA policy assignments from pilot to All Users (with exclusions)
- [ ] Communicate rollout schedule to user population
- [ ] Prepare helpdesk for increased ticket volume
- [ ] Document rollout progress

#### Task 7.3: User Communication
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Steps**:
- [ ] Finalize user guides based on pilot feedback
- [ ] Create all-staff communication
- [ ] Schedule training sessions (if required)
- [ ] Publish guides to internal portal
- [ ] Send rollout notification emails
- [ ] Prepare FAQ updates based on helpdesk feedback

#### Task 7.4: Hypercare Support Period
**Owner**: Olli Ojala
**Status**: ⬜ Not Started
**Duration**: 2 weeks post-rollout

**Steps**:
- [ ] Establish hypercare support hours
- [ ] Monitor Intune compliance dashboards daily
- [ ] Monitor CA sign-in logs daily
- [ ] Monitor MCAS alerts daily
- [ ] Track and resolve helpdesk tickets related to rollout
- [ ] Document common issues and resolutions
- [ ] Create knowledge base articles for recurring issues
- [ ] Conduct post-hypercare review

---

### Phase 8: Documentation & Handover
**Status**: Pending Phase 7 Completion
**Duration**: 1 week
**Priority**: Medium - Operational sustainability
**Prerequisites**: Hypercare complete

#### Task 8.1: Create Operations Documentation
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Documents to Create**:
- [ ] Policy configuration reference guide
- [ ] Troubleshooting runbook
- [ ] Selective wipe procedure
- [ ] Device enrollment guides (admin)
- [ ] Compliance reporting guide

#### Task 8.2: Knowledge Transfer
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Steps**:
- [ ] Schedule handover sessions with QPS IT team
- [ ] Walk through all policies and configurations
- [ ] Demonstrate key administrative tasks
- [ ] Review monitoring and alerting procedures
- [ ] Document escalation paths
- [ ] Obtain sign-off on handover completion

#### Task 8.3: Project Closure
**Owner**: Olli Ojala
**Status**: ⬜ Not Started

**Steps**:
- [ ] Compile lessons learned document
- [ ] Update detailed design document with any changes
- [ ] Archive project documentation
- [ ] Conduct project close-out meeting
- [ ] Obtain project sign-off

---

## Risk Mitigation

### User Adoption Risks
| Risk | Mitigation |
|------|------------|
| User resistance to MAM PIN | Clear communication on why, allow biometrics |
| Confusion about BYOD vs corporate policies | Tailored user guides per scenario |
| Helpdesk ticket surge | Pre-training helpdesk, extended hypercare |

### Technical Risks
| Risk | Mitigation |
|------|------------|
| CA policy locks out users | Break-glass accounts in exclusion groups |
| MAM policy too restrictive | Pilot testing before production rollout |
| ABM/Android Enterprise sync issues | Verify integration before enrollment |
| MCAS session control performance | Test with pilot users first |

### Privacy Risks
| Risk | Mitigation |
|------|------------|
| User concern about personal data | MAM = app-level only, not device |
| Selective wipe trust | Document and demonstrate during rollout |

---

## Implementation Status Dashboard

**Current Phase**: Phase 0 - Planning Complete ✅
**Next Action**: Begin Phase 1 - Foundation Setup
**Progress**: 0/8 phases complete
**Blocker Status**: None - Ready to proceed

**Phase Summary**:
| Phase | Status | Tasks | Completed |
|-------|--------|-------|-----------|
| 0. Planning | ✅ Complete | 4 | 4 |
| 1. Foundation | ⬜ Not Started | 3 | 0 |
| 2. MAM Policies | ⬜ Not Started | 3 | 0 |
| 3. MDM Policies | ⬜ Not Started | 6 | 0 |
| 4. Conditional Access | ⬜ Not Started | 4 | 0 |
| 5. MCAS | ⬜ Not Started | 2 | 0 |
| 6. Pilot Testing | ⬜ Not Started | 7 | 0 |
| 7. Production Rollout | ⬜ Not Started | 4 | 0 |
| 8. Documentation | ⬜ Not Started | 3 | 0 |

---

## Appendix

### Policy Naming Convention
All policies follow the naming convention: `Orro - QPS - [Platform] [Policy Type] [Purpose]`

### Key Portal URLs
- Intune Admin Center: https://intune.microsoft.com
- Entra Admin Center: https://entra.microsoft.com
- Microsoft Defender for Cloud Apps: https://security.microsoft.com
- Apple Business Manager: https://business.apple.com

### Contact Information
| Role | Name | Contact |
|------|------|---------|
| Cloud Project Engineer | Olli Ojala | olli.ojala@orro.group |
| Program Manager | George Alex | TBD |

---

**Document Version**: 1.0
**Last Updated**: 2025-08-22
**Next Review**: After Phase 1 completion
