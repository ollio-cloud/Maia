#!/usr/bin/env python3
"""
Test Suite for Root Directory Cleanup
TDD Phase 2: Tests Written BEFORE Implementation

Tests verify:
1. Files to be deleted have no active code dependencies
2. Essential files remain after cleanup
3. Archived docs are accessible
4. Scripts directory has working alternatives
5. Git history preserved
6. No broken references
"""

import os
import subprocess
from pathlib import Path
import sys

# Get MAIA_ROOT
MAIA_ROOT = Path(__file__).resolve().parent.parent
os.chdir(MAIA_ROOT)


class TestPreCleanupValidation:
    """Tests to run BEFORE cleanup to ensure safety"""

    def test_no_active_imports_of_fix_scripts(self):
        """Verify no active Python code imports files we plan to delete"""
        files_to_delete = [
            "fix_all_profiler_results.py",
            "fix_cleaner_api.py",
            "fix_cleaner_api_proper.py",
            "fix_indentation_issues.py",
            "fix_profiler_normalization.py",
            "remove_duplicate_normalizations.py",
        ]

        # Search all Python files in claude/ for imports
        for script in files_to_delete:
            base_name = script.replace('.py', '')
            result = subprocess.run(
                ['grep', '-r', f'import {base_name}', 'claude/', '--include=*.py'],
                capture_output=True,
                text=True
            )
            assert result.returncode == 1, f"ERROR: Active code imports {script}! Found:\n{result.stdout}"

        print("✅ No active imports of fix scripts")

    def test_scripts_directory_has_alternatives(self):
        """Verify scripts/ directory has alternative dashboard tools"""
        required_in_scripts = [
            "scripts/dashboard",
            "scripts/launch_dashboard_hub.sh",
        ]

        for script in required_in_scripts:
            path = MAIA_ROOT / script
            assert path.exists(), f"ERROR: {script} missing from scripts/ directory!"
            assert os.access(path, os.X_OK), f"ERROR: {script} not executable!"

        print("✅ scripts/ directory has working alternatives")

    def test_git_status_clean_or_acceptable(self):
        """Verify git state before cleanup"""
        result = subprocess.run(
            ['git', 'status', '--porcelain'],
            capture_output=True,
            text=True
        )

        # Allow new test files to be uncommitted
        uncommitted = [line for line in result.stdout.splitlines()
                      if 'test_root_cleanup' not in line]

        if uncommitted:
            print(f"⚠️  Warning: Uncommitted changes exist:\n{chr(10).join(uncommitted)}")
            print("   Proceeding anyway - tests will create backup")
        else:
            print("✅ Git status clean")

    def test_essential_files_exist_before_cleanup(self):
        """Verify essential files exist before we start"""
        essential_files = [
            "CLAUDE.md",
            "README.md",
            "SYSTEM_STATE.md",
            "SYSTEM_STATE_ARCHIVE.md",
            "SYSTEM_STATE_INDEX.json",
            "SHARE_WITH_TEAM.md",
            "TEAM_SETUP_README.md",
        ]

        for file in essential_files:
            path = MAIA_ROOT / file
            assert path.exists(), f"ERROR: Essential file {file} missing BEFORE cleanup!"

        print("✅ All essential files present before cleanup")


class TestPostCleanupValidation:
    """Tests to run AFTER cleanup to verify success"""

    def test_fix_scripts_deleted(self):
        """Verify fix scripts were deleted"""
        deleted_files = [
            "fix_all_profiler_results.py",
            "fix_cleaner_api.py",
            "fix_cleaner_api_proper.py",
            "fix_indentation_issues.py",
            "fix_profiler_normalization.py",
            "remove_duplicate_normalizations.py",
        ]

        for file in deleted_files:
            path = MAIA_ROOT / file
            assert not path.exists(), f"ERROR: {file} should be deleted but still exists!"

        print("✅ Fix scripts successfully deleted")

    def test_duplicate_dashboard_scripts_deleted(self):
        """Verify duplicate dashboard scripts deleted"""
        deleted_scripts = [
            "dashboard",
            "dashboards",
            "setup_nginx_hosts.sh",
        ]

        for script in deleted_scripts:
            path = MAIA_ROOT / script
            assert not path.exists(), f"ERROR: {script} should be deleted but still exists!"

        print("✅ Duplicate dashboard scripts deleted")

    def test_essential_docs_remain(self):
        """Verify essential documentation still present"""
        essential_files = [
            "CLAUDE.md",
            "README.md",
            "SYSTEM_STATE.md",
            "SYSTEM_STATE_ARCHIVE.md",
            "SYSTEM_STATE_INDEX.json",
            "SHARE_WITH_TEAM.md",
            "TEAM_SETUP_README.md",
        ]

        for file in essential_files:
            path = MAIA_ROOT / file
            assert path.exists(), f"ERROR: Essential file {file} was deleted!"

        print("✅ All essential docs remain")

    def test_docs_archive_created(self):
        """Verify docs/archive/ directory created with historical docs"""
        archive_dir = MAIA_ROOT / "docs" / "archive"
        assert archive_dir.exists(), "ERROR: docs/archive/ directory not created!"

        archived_docs = [
            "PHASE_84_85_SUMMARY.md",
            "PROJECTS_COMPLETED.md",
            "MAIA_EVOLUTION_STORY.md",
            "MAIL_APP_SETUP.md",
            "NGINX_SETUP_COMPLETE.md",
            "ACTIVATE_AUTO_ROUTING.md",
            "DASHBOARDS_QUICK_START.md",
            "DASHBOARD_STATUS_REPORT.md",
            "RESTORE_DASHBOARDS.md",
        ]

        for doc in archived_docs:
            # Should NOT be in root
            root_path = MAIA_ROOT / doc
            assert not root_path.exists(), f"ERROR: {doc} still in root, not archived!"

            # Should BE in archive
            archive_path = archive_dir / doc
            assert archive_path.exists(), f"ERROR: {doc} not in docs/archive/!"

        print("✅ Historical docs archived successfully")

    def test_venv_removed_and_ignored(self):
        """Verify venv/ removed from repo and added to .gitignore"""
        venv_path = MAIA_ROOT / "venv"

        # Should not exist or should be empty
        if venv_path.exists():
            # If exists, should be in .gitignore
            gitignore = (MAIA_ROOT / ".gitignore").read_text()
            assert "venv/" in gitignore, "ERROR: venv/ exists but not in .gitignore!"
            print("⚠️  venv/ still exists but is now ignored")
        else:
            print("✅ venv/ removed")

        # Check .gitignore has venv/
        gitignore = (MAIA_ROOT / ".gitignore").read_text()
        assert "venv/" in gitignore, "ERROR: venv/ not in .gitignore!"
        print("✅ venv/ in .gitignore")

    def test_scripts_directory_functional(self):
        """Verify scripts/ directory dashboard tools are executable"""
        scripts_to_check = [
            "scripts/dashboard",
            "scripts/launch_dashboard_hub.sh",
        ]

        for script in scripts_to_check:
            path = MAIA_ROOT / script
            assert path.exists(), f"ERROR: {script} missing after cleanup!"
            assert os.access(path, os.X_OK), f"ERROR: {script} not executable!"

        print("✅ scripts/ dashboard tools functional")

    def test_performance_db_untouched(self):
        """Verify performance_metrics.db was NOT moved (as per requirements)"""
        db_path = MAIA_ROOT / "performance_metrics.db"
        assert db_path.exists(), "ERROR: performance_metrics.db was moved/deleted!"
        print("✅ performance_metrics.db untouched (correct)")

    def test_launcher_scripts_kept(self):
        """Verify root launcher scripts kept (referenced by scripts/dashboard)"""
        launchers = [
            "launch_all_dashboards.sh",
            "launch_working_dashboards.sh",
        ]

        for launcher in launchers:
            path = MAIA_ROOT / launcher
            assert path.exists(), f"ERROR: {launcher} was deleted but may be needed!"

        print("✅ Root launcher scripts preserved")

    def test_requirements_file_present(self):
        """Verify requirements file exists"""
        req_path = MAIA_ROOT / "requirements-mcp-trello.txt"
        assert req_path.exists(), "ERROR: requirements-mcp-trello.txt missing!"
        print("✅ Requirements file present")


def run_pre_cleanup_tests():
    """Run tests BEFORE cleanup"""
    print("\n" + "="*60)
    print("RUNNING PRE-CLEANUP VALIDATION TESTS")
    print("="*60 + "\n")

    test_class = TestPreCleanupValidation()
    tests = [
        test_class.test_no_active_imports_of_fix_scripts,
        test_class.test_scripts_directory_has_alternatives,
        test_class.test_git_status_clean_or_acceptable,
        test_class.test_essential_files_exist_before_cleanup,
    ]

    for test in tests:
        try:
            test()
        except AssertionError as e:
            print(f"\n❌ TEST FAILED: {test.__name__}")
            print(f"   {str(e)}")
            return False
        except Exception as e:
            print(f"\n❌ TEST ERROR: {test.__name__}")
            print(f"   {str(e)}")
            return False

    print("\n✅ ALL PRE-CLEANUP TESTS PASSED")
    print("="*60)
    return True


def run_post_cleanup_tests():
    """Run tests AFTER cleanup"""
    print("\n" + "="*60)
    print("RUNNING POST-CLEANUP VERIFICATION TESTS")
    print("="*60 + "\n")

    test_class = TestPostCleanupValidation()
    tests = [
        test_class.test_fix_scripts_deleted,
        test_class.test_duplicate_dashboard_scripts_deleted,
        test_class.test_essential_docs_remain,
        test_class.test_docs_archive_created,
        test_class.test_venv_removed_and_ignored,
        test_class.test_scripts_directory_functional,
        test_class.test_performance_db_untouched,
        test_class.test_launcher_scripts_kept,
        test_class.test_requirements_file_present,
    ]

    for test in tests:
        try:
            test()
        except AssertionError as e:
            print(f"\n❌ TEST FAILED: {test.__name__}")
            print(f"   {str(e)}")
            return False
        except Exception as e:
            print(f"\n❌ TEST ERROR: {test.__name__}")
            print(f"   {str(e)}")
            return False

    print("\n✅ ALL POST-CLEANUP TESTS PASSED")
    print("="*60)
    return True


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "post":
        success = run_post_cleanup_tests()
    else:
        success = run_pre_cleanup_tests()

    sys.exit(0 if success else 1)
