# Root Directory Cleanup - Requirements Document
**Date**: 2025-10-22
**TDD Phase 1**: Requirements Discovery Complete

## Decisions Made
- **Q1 (performance_metrics.db)**: **Option C** - Leave at root for now, fix in separate task
- **Q2 (Dashboard scripts)**: **Option C** - Check scripts/ versions first, keep best one
- **Q3 (Documentation)**: **Option B** - Archive docs too (they're historical)

## Scripts Analysis Results

### Dashboard Scripts Comparison:
1. **Root `./dashboard`** (3.2K):
   - Uses `dashboard_service_manager.py`
   - More sophisticated (service manager approach)
   - Hardcoded path: `/Users/naythan/git/maia`

2. **scripts/dashboard** (1.5K):
   - Uses direct `launch_all_dashboards.sh` call
   - Simpler (wrapper script)
   - Hardcoded path: `/Users/naythandawe/git/maia`

3. **Root launchers**:
   - `launch_all_dashboards.sh` (2.2K) - Full launcher
   - `launch_working_dashboards.sh` (1.6K) - Filtered launcher

4. **scripts/launch_dashboard_hub.sh** (400B):
   - Launches single hub dashboard
   - Hardcoded path: `/Users/naythan/git/maia`

**Decision**: Keep `scripts/` versions (smaller, delegating), delete root duplicates

---

## Final Requirements

### FR1: Delete One-Time Fix Scripts (SAFE - No Dependencies)
**Files to delete** (6 files):
- `fix_all_profiler_results.py`
- `fix_cleaner_api.py`
- `fix_cleaner_api_proper.py`
- `fix_indentation_issues.py`
- `fix_profiler_normalization.py`
- `remove_duplicate_normalizations.py`

**Acceptance Criteria**:
- Files removed from root
- No broken imports in active code
- Historical docs still reference them (preserved in git history)

### FR2: Delete Duplicate Dashboard Scripts (Keep scripts/ versions)
**Files to delete** (3 files):
- `dashboard` (root) - duplicate of scripts/dashboard
- `dashboards` (root) - old/unknown version
- `setup_nginx_hosts.sh` - one-time setup

**Rationale**: scripts/ directory already has working versions

**Acceptance Criteria**:
- Root scripts removed
- scripts/ versions remain functional
- Mac team member can still use dashboard tools

### FR3: Archive Historical Documentation
**Files to move to docs/archive/** (9 files):
- PHASE_84_85_SUMMARY.md
- PROJECTS_COMPLETED.md
- MAIA_EVOLUTION_STORY.md
- MAIL_APP_SETUP.md
- NGINX_SETUP_COMPLETE.md
- ACTIVATE_AUTO_ROUTING.md
- DASHBOARDS_QUICK_START.md
- DASHBOARD_STATUS_REPORT.md
- RESTORE_DASHBOARDS.md

**Acceptance Criteria**:
- Files moved to docs/archive/
- Still accessible via git and file browser
- Team can reference if needed

### FR4: Remove venv/ Directory
**Action**: Remove from repo, add to .gitignore

**Acceptance Criteria**:
- venv/ not in repo
- .gitignore contains "venv/"
- Future venvs won't be committed

### FR5: Keep Dashboard Launchers (scripts/ only)
**Files to KEEP** (in scripts/):
- scripts/dashboard
- scripts/launch_dashboard_hub.sh
- launch_all_dashboards.sh (root - referenced by scripts/dashboard)
- launch_working_dashboards.sh (root - may be referenced)

**Rationale**: Mac team member needs these

### FR6: Do NOT Move performance_metrics.db
**Decision**: Leave at root (fix path conflicts in separate task)

**Rationale**:
- 6 tools have conflicting path expectations
- Requires careful refactoring + testing
- Out of scope for cleanup task

---

## Non-Functional Requirements

### NFR1: Zero Breakage Guarantee
**Test Coverage**:
1. Verify no active code imports deleted files
2. Check scripts/ dashboard tools still work
3. Confirm essential docs still accessible
4. Validate git history preserved

### NFR2: Rollback Capability
**Implementation**:
- Git commit before cleanup
- Document all changes in commit message
- Can revert with `git revert <commit>`

### NFR3: Team Portability
**Constraint**:
- Dashboard scripts in scripts/ have hardcoded paths
- **Acceptable**: Team members expected to update paths for their environment
- **Future work**: Could make scripts use $MAIA_ROOT

---

## Out of Scope (Future Tasks)

1. **Fix performance_metrics.db path conflicts** (separate ticket)
2. **Make dashboard scripts use $MAIA_ROOT** (separate ticket)
3. **Create master requirements.txt** (separate ticket)
4. **Update team onboarding docs** (can do after cleanup if needed)

---

## Test Plan

### Pre-Cleanup Tests:
1. **test_no_active_imports()** - Verify deleted files not imported
2. **test_scripts_directory_exists()** - Ensure scripts/ has alternatives
3. **test_git_status_clean()** - Start with clean git state

### Post-Cleanup Tests:
4. **test_essential_docs_present()** - CLAUDE.md, README.md, etc. still there
5. **test_archived_docs_accessible()** - docs/archive/ created and populated
6. **test_scripts_functional()** - scripts/dashboard exists and is executable
7. **test_venv_ignored()** - .gitignore contains venv/
8. **test_no_broken_references()** - No errors from missing files

---

## File Count Summary

**Before**: 28 files + venv/
**After**: 10 files + docs/archive/ (9 files) + scripts/ (maintained)

**Reduction**: 68% fewer root files (18 deleted/archived)

---

## Risk Mitigation

**Risk 1**: Deleting wrong dashboard script
- **Mitigation**: Compared all versions, keeping scripts/ + 2 root launchers

**Risk 2**: Breaking Mac team member's workflow
- **Mitigation**: Keeping all dashboard tools in scripts/

**Risk 3**: Losing important historical context
- **Mitigation**: Archiving (not deleting), preserving git history

---

## Requirements Sign-Off

✅ **User confirmed decisions**: Q1=C, Q2=C, Q3=B
✅ **Dependencies analyzed**: No active code dependencies on deleted files
✅ **Alternatives verified**: scripts/ directory has working versions
✅ **Risks identified**: None blocking, all mitigated

**Ready for Phase 2**: Write Tests
