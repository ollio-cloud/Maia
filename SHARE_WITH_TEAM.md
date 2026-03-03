# Share This With Your Team

**Maia Team Repository**: https://github.com/naythan-orro/maia-team-share

---

## Quick Start for Team Members

### For Windows Laptops (WSL)

1. **Clone the repository**:
   ```bash
   git clone https://github.com/naythan-orro/maia-team-share.git
   cd maia-team-share
   ```

2. **Run prerequisite setup** (PowerShell as Administrator):
   ```powershell
   cd maia-team-share\claude\tools\sre
   .\setup_wsl_prerequisites.ps1
   ```

3. **Follow the onboarding guide**:
   - Read: `TEAM_SETUP_README.md`
   - Then: `claude/tools/sre/TEAM_ONBOARDING_WSL.md`

4. **Configure your credentials**:
   ```bash
   cp .env.example .env
   # Edit .env with your API keys
   ```

### For macOS

1. **Clone the repository**:
   ```bash
   git clone https://github.com/naythan-orro/maia-team-share.git ~/git/maia
   cd ~/git/maia
   ```

2. **Install dependencies**:
   ```bash
   pip3 install -r requirements.txt
   ```

3. **Configure credentials**:
   ```bash
   cp .env.example .env
   # Edit .env with your API keys
   ```

---

## What You're Getting

- ✅ **Full Maia codebase** (51 agents, 205+ tools)
- ✅ **Complete documentation** (onboarding, technical guides, system docs)
- ✅ **Automated setup** (PowerShell script for Windows prerequisites)
- ✅ **Templates & examples** (.env.example, credential templates)

---

## What's NOT Included (Intentionally)

- ❌ Personal databases (you'll create fresh ones)
- ❌ API credentials (use templates provided)
- ❌ Personal configurations (customize for your environment)
- ❌ Log history (fresh start)

---

## Documentation

- **Quick Start**: `TEAM_SETUP_README.md`
- **WSL Onboarding**: `claude/tools/sre/TEAM_ONBOARDING_WSL.md` (600 lines, step-by-step)
- **WSL Technical Guide**: `claude/tools/sre/WSL_RESTORE_GUIDE.md` (400 lines, troubleshooting)
- **System Overview**: `CLAUDE.md`
- **Recent Changes**: `SYSTEM_STATE.md`
- **All Capabilities**: `claude/context/core/capability_index.md`

---

## Estimated Setup Time

- **First-time setup**: 30-60 minutes
  - 10 min: Run prerequisite script
  - 5 min: Complete WSL setup
  - 10 min: Clone and configure
  - 5 min: Verify installation

- **Subsequent updates**: `git pull` (seconds)

---

## Getting Help

1. Check `TEAM_ONBOARDING_WSL.md` troubleshooting section
2. Review `TEAM_SETUP_README.md`
3. Ask your team lead
4. Check documentation in `claude/context/`

---

## Welcome to Maia! 🎉

This repository represents a sophisticated AI agent system with:
- 51 specialized agents (Azure, Security, SRE, Recruitment, etc.)
- 205+ tools (automation, analysis, integration)
- Multi-agent orchestration
- Disaster recovery system
- Cross-platform support (macOS + Windows WSL)

**Start here**: `TEAM_SETUP_README.md`

---

**Repository**: https://github.com/naythan-orro/maia-team-share
**Last Updated**: 2025-10-22
