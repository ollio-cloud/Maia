# Maia Team Onboarding Guide

**Version**: 1.0 (Post-WSL Verification)
**Last Updated**: 2025-10-22
**Status**: ✅ Tested and verified on WSL2 Windows laptop

---

## Quick Start (3 Steps)

```bash
# 1. Clone the repository
git clone https://github.com/naythan-orro/maia-team-share.git
cd maia-team-share

# 2. Verify paths (should auto-detect)
python3 claude/tools/core/path_manager.py

# 3. You're ready! System works immediately.
```

That's it. No configuration files to edit, no environment variables to set, no paths to update.

---

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Platform-Specific Setup](#platform-specific-setup)
3. [Cloning the Repository](#cloning-the-repository)
4. [Verification](#verification)
5. [Optional Configuration](#optional-configuration)
6. [Optional Packages](#optional-packages)
7. [Troubleshooting](#troubleshooting)
8. [Understanding Maia's Architecture](#understanding-maias-architecture)

---

## System Requirements

### Core Requirements (All Platforms)

✅ **Python 3.8+** (Python 3.12+ recommended)
✅ **Git 2.0+**
✅ **GitHub Access** (with your credentials)

### Platform Support

✅ **macOS** (Tested on macOS with 32GB RAM)
✅ **Windows with WSL2** (Tested on Windows laptop with Ubuntu WSL2)
✅ **Linux** (Ubuntu, Debian, etc.)
❌ **Native Windows** (Not supported - use WSL2 instead)

---

## Platform-Specific Setup

Choose your platform:

### Windows (WSL2) - Recommended for Windows Users

**Why WSL2?**
- Full Linux compatibility (bash, Python, git work natively)
- Better file I/O performance than native Windows
- Seamless VSCode integration
- Maia designed for Unix-like environments

**1. Install WSL2**

```powershell
# Open PowerShell as Administrator
wsl --install

# Or specify Ubuntu:
wsl --install -d Ubuntu-22.04

# Verify WSL2:
wsl --list --verbose
```

**2. Install Python & Git in WSL**

```bash
# Open WSL terminal (run 'wsl' in PowerShell)
sudo apt update
sudo apt install python3 python3-pip git curl

# Verify installations
python3 --version  # Should be 3.8+
git --version
```

**3. Install VSCode with Remote-WSL Extension**

- Download VSCode: https://code.visualstudio.com/
- Install extension: `ms-vscode-remote.remote-wsl`
- Open WSL from VSCode: Press F1 → "WSL: Connect to WSL"

**4. Set Up Git Credentials**

```bash
# Configure Git
git config --global user.name "Your Name"
git config --global user.email "your.email@orro.group"

# Optional: Use Windows Credential Manager
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"
```

---

### macOS - Direct Setup

**1. Install Homebrew** (if not already installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**2. Install Python & Git**

```bash
brew install python@3.12 git

# Verify
python3 --version
git --version
```

**3. Configure Git**

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@orro.group"
```

---

### Linux (Ubuntu/Debian)

**1. Install Python & Git**

```bash
sudo apt update
sudo apt install python3 python3-pip git curl

# Verify
python3 --version
git --version
```

**2. Configure Git**

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@orro.group"
```

---

## Cloning the Repository

### Choose Your Installation Location

**Recommended Paths:**
- **WSL**: `~/maia-team-share` (fast Linux filesystem)
- **macOS**: `~/git/maia-team-share` or `~/projects/maia-team-share`
- **Linux**: `~/projects/maia-team-share`

**⚠️ WSL Important**: Do NOT clone to `/mnt/c/Users/...` (Windows filesystem) - very slow I/O.

### Clone Command

```bash
# Navigate to your preferred location
cd ~  # or cd ~/projects

# Clone the repository
git clone https://github.com/naythan-orro/maia-team-share.git

# Navigate into directory
cd maia-team-share
```

**Authentication Options:**
1. **HTTPS with PAT** (Personal Access Token): GitHub will prompt for credentials
2. **SSH**: Set up SSH keys first: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

---

## Verification

### 1. Verify Path Auto-Detection

```bash
python3 claude/tools/core/path_manager.py
```

**Expected Output:**
```
🗂️  Maia Path Manager
==================================================
MAIA_ROOT:     /home/yourname/maia-team-share
Tools:         /home/yourname/maia-team-share/claude/tools
Data:          /home/yourname/maia-team-share/claude/data
Agents:        /home/yourname/maia-team-share/claude/agents
Commands:      /home/yourname/maia-team-share/claude/commands
Context:       /home/yourname/maia-team-share/claude/context
Hooks:         /home/yourname/maia-team-share/claude/hooks
==================================================

✓ Verification:
✅ Root: /home/yourname/maia-team-share
✅ Tools: /home/yourname/maia-team-share/claude/tools
✅ Data: /home/yourname/maia-team-share/claude/data
```

✅ **All paths should show green checkmarks** - system is working!

### 2. Verify Directory Structure

```bash
ls -la claude/
```

**Expected Directories:**
- `agents/` - 49 specialized agent definitions
- `commands/` - Custom slash commands
- `context/` - System context and documentation
- `data/` - Databases and data files
- `hooks/` - 32 system hooks (Python/bash)
- `tools/` - 200+ tools organized by domain

### 3. Test Core Functionality

```bash
# Test smart context loader (bash hook)
bash claude/hooks/load_system_state_smart.sh "test system health"

# Should output phase information and statistics
```

---

## Optional Configuration

### 1. Environment Variables (Optional - Only if Needed)

Maia has **auto-detection** and doesn't require environment variables. However, you can optionally set them:

```bash
# Only if you want to override auto-detection
echo 'export MAIA_ROOT=~/maia-team-share' >> ~/.bashrc
source ~/.bashrc
```

**When to set MAIA_ROOT:**
- Multiple Maia installations
- Custom installation locations
- Development/testing scenarios

**Default behavior (no env var)**: Auto-detects from file location ✅ Recommended

### 2. API Keys & Service Credentials (As Needed)

Maia includes template `.env` file for service integrations:

```bash
# Copy template
cp .env.example .env

# Edit with your credentials (if you need these services)
nano .env
```

**Available Integrations** (configure only what you need):
- `ANTHROPIC_API_KEY` - Claude API access (for AI features)
- `CONFLUENCE_API_TOKEN` - Confluence integration
- `MAIA_ONEDRIVE_PATH` - OneDrive backup location
- `MAIA_VAULT_PASSWORD` - Credential vault encryption

**Note**: Most team members won't need all integrations. Configure only what you use.

---

## Optional Packages

### Core Python Packages (Already Installed)

✅ `anthropic` - Claude API client
✅ `requests` - HTTP library
✅ `pydantic` - Data validation

### Optional Packages (Install as Needed)

```bash
# Testing framework
pip3 install pytest

# Database ORM (for governance tools)
pip3 install sqlalchemy

# API services (for service tools)
pip3 install fastapi uvicorn
```

### Optional System Tools

**Docker** (for containerized services):
- WSL: https://docs.docker.com/engine/install/ubuntu/
- macOS: https://docs.docker.com/desktop/install/mac-install/

**Ollama** (for local LLM support - 99.3% cost savings):
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

---

## Troubleshooting

### Issue 1: "python3: command not found"

**Solution:**
```bash
# WSL/Linux:
sudo apt install python3 python3-pip

# macOS:
brew install python@3.12
```

---

### Issue 2: "git: command not found"

**Solution:**
```bash
# WSL/Linux:
sudo apt install git

# macOS:
brew install git
```

---

### Issue 3: Path Auto-Detection Shows ❌ Errors

**Symptoms:**
```
❌ Root: /wrong/path
❌ Tools: /wrong/path/claude/tools
```

**Solution:**
```bash
# Verify you're in the Maia directory
pwd  # Should show path ending in 'maia-team-share'

# Verify claude/ folder exists
ls -la claude/

# If in wrong directory, cd to correct location:
cd ~/maia-team-share  # or wherever you cloned it
python3 claude/tools/core/path_manager.py
```

---

### Issue 4: Git Authentication Fails

**HTTPS Authentication:**
```bash
# GitHub will prompt for username + Personal Access Token (PAT)
# Create PAT at: https://github.com/settings/tokens
# Scopes needed: repo (Full control of private repositories)
```

**SSH Authentication:**
```bash
# Generate SSH key (if you don't have one)
ssh-keygen -t ed25519 -C "your.email@orro.group"

# Add to GitHub: https://github.com/settings/keys
cat ~/.ssh/id_ed25519.pub  # Copy this to GitHub

# Update remote to use SSH
git remote set-url origin git@github.com:naythan-orro/maia-team-share.git
```

---

### Issue 5: Slow Performance on WSL

**Symptom**: Git commands slow, file saves lag

**Cause**: Maia cloned to Windows filesystem (`/mnt/c/...`)

**Solution**: Move to WSL filesystem
```bash
# Move from Windows to WSL filesystem
mv /mnt/c/Users/yourname/maia-team-share ~/maia-team-share
cd ~/maia-team-share

# Verify performance improvement
time git status  # Should be <1 second
```

---

### Issue 6: VSCode Can't Find Files (WSL)

**Solution:**
1. Install VSCode extension: `ms-vscode-remote.remote-wsl`
2. Open folder from WSL terminal:
   ```bash
   cd ~/maia-team-share
   code .
   ```
3. VSCode will connect to WSL and open the folder

---

## Understanding Maia's Architecture

### Zero-Configuration Portability (Phase 74)

Maia uses **intelligent path auto-detection** instead of configuration files:

**How it Works:**
1. Any tool calls `get_maia_root()` from path_manager.py
2. Path manager uses 4 fallback strategies:
   - Environment variable (optional override)
   - **File location** (primary: walks up from path_manager.py location)
   - Current working directory (checks for `claude/` folder)
   - Parent directory search (up to 3 levels)
3. Result: System works anywhere it's cloned

**Benefits:**
- ✅ No hardcoded paths (132 files updated in Phase 74)
- ✅ Works with any username
- ✅ Works in any directory
- ✅ Works on any OS (macOS, WSL, Linux)
- ✅ Zero configuration required

### Cross-Platform Disaster Recovery (Phase 135.5)

Maia supports disaster recovery across platforms:
- Create backups on macOS → Restore on WSL
- Create backups on WSL → Restore on macOS
- Backups stored in OneDrive (syncs across devices)

See: `claude/tools/sre/WSL_RESTORE_GUIDE.md` for backup/restore details

---

## What's Next?

### Recommended First Steps

1. **Explore the system:**
   ```bash
   # View available tools
   ls claude/tools/

   # View available agents
   ls claude/agents/

   # Read system documentation
   cat SYSTEM_STATE.md | head -100
   ```

2. **Set up your preferred IDE:**
   - **VSCode (WSL)**: Already covered above
   - **VSCode (macOS/Linux)**: Open folder directly
   - **PyCharm/Other**: Open `maia-team-share` folder

3. **Configure integrations you need:**
   - Edit `.env` with your API keys (optional)
   - Install optional packages for features you use

4. **Review documentation:**
   - `README.md` - System overview and capabilities
   - `SYSTEM_STATE.md` - Development history and phases
   - `claude/context/core/portability_guide.md` - Path system details

---

## Getting Help

### Resources

- **System Documentation**: All docs in `claude/context/core/`
- **Tool Capabilities**: `claude/context/core/capability_index.md` (200+ tools)
- **Agent Reference**: `claude/context/core/agents.md` (49 agents)
- **Portability Guide**: `claude/context/core/portability_guide.md`
- **WSL Restoration**: `claude/tools/sre/WSL_RESTORE_GUIDE.md`

### Common Questions

**Q: Do I need to set MAIA_ROOT environment variable?**
A: No, path auto-detection handles this automatically.

**Q: Do I need to install all Python packages?**
A: No, install only packages for features you need (see Optional Packages section).

**Q: Can I use native Windows (not WSL)?**
A: No, Maia requires Unix-like environment (bash, Python, git). Use WSL2.

**Q: Where should I clone on WSL?**
A: `~/maia-team-share` (WSL filesystem). NOT `/mnt/c/...` (slow Windows filesystem).

**Q: How do I know if system is working?**
A: Run `python3 claude/tools/core/path_manager.py` - all checkmarks should be green.

---

## Quick Reference

### Essential Commands

```bash
# Verify paths
python3 claude/tools/core/path_manager.py

# Check Python version
python3 --version

# Check Git status
git status

# Pull latest changes
git pull

# Open in VSCode (WSL)
code .

# Test smart loader
bash claude/hooks/load_system_state_smart.sh "query"
```

### Directory Structure

```
maia-team-share/
├── claude/
│   ├── agents/           # 49 specialized agents
│   ├── commands/         # Custom slash commands
│   ├── context/          # System documentation
│   ├── data/             # Databases and data files
│   ├── hooks/            # 32 system hooks
│   └── tools/            # 200+ tools by domain
├── scripts/              # Utility scripts
├── .env                  # Environment variables (template)
├── README.md             # System overview
├── SYSTEM_STATE.md       # Development history
└── TEAM_ONBOARDING.md    # This file
```

---

## Welcome to Maia!

**You're ready to go.** The system is designed to work immediately after cloning with zero configuration.

For questions or issues not covered here, review the troubleshooting section or check the documentation in `claude/context/core/`.

---

**Document Version**: 1.0 (Post-WSL Verification)
**Last Updated**: 2025-10-22
**Tested On**: WSL2 (Ubuntu), Python 3.12.3, Git 2.43.0
**Status**: ✅ Production Ready
