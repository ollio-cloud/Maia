# Maia - My AI Agent

## 🚀 Quick Start

**New Team Member?** See [TEAM_SETUP_README.md](TEAM_SETUP_README.md) for complete setup instructions.

**3-Step Setup:**
1. Clone repository: `git clone https://github.com/naythan-orro/maia-team-share.git`
2. Set MAIA_ROOT: `export MAIA_ROOT=/path/to/maia-team-share` (add to ~/.bashrc or ~/.zshrc)
3. Verify paths: `python3 claude/tools/core/path_manager.py`

**Optional Dependencies:**
- Python packages: `pip3 install python-dotenv anthropic requests` (for standalone tools)
- Docker Desktop (for ServiceDesk dashboard and containerized services)
- Ollama (for local LLM inference - 99.3% cost savings)

**WSL Users?** See [WSL_RESTORE_GUIDE.md](claude/tools/sre/WSL_RESTORE_GUIDE.md) for Windows-specific setup.

---

## Repository
**GitHub**: https://github.com/naythan-orro/maia-team-share
**Version Control**: Git repository - works anywhere (macOS, WSL, Linux)
**Status**: ✅ Team-ready (Phase 137 - personal data removed, templates provided)

## Overview
Maia is a personal AI infrastructure system featuring sophisticated workflow orchestrations through a multi-agent system and advanced automation capabilities. The system follows enterprise-grade design principles:

- **Single Responsibility**: Focused domain expertise per agent/tool
- **Composable Architecture**: Seamless multi-agent orchestration
- **Production Ready**: Comprehensive error handling and monitoring
- **Evidence-Based**: Performance tracking and continuous learning
- **Security First**: 100% local processing options, sandboxed execution
- **Privacy Focused**: Email RAG, conversation RAG, and LLM inference run locally

---

## 🎯 Core Capabilities

### 📊 Information Management System ⭐ **PHASE 115 - PRODUCTION**
**Complete GTD ecosystem with executive intelligence** (October 2025):

**Production Systems** (4 tools, 2,750 lines):
- **Enhanced Daily Briefing** (`enhanced_daily_briefing_strategic.py`)
  - Executive intelligence layer with 0-10 impact scoring
  - AI recommendations with 60-90% confidence levels
  - Relationship tracking and stakeholder sentiment
  - 1-hour daily time savings

- **Meeting Context Auto-Assembly** (`meeting_context_auto_assembly.py`)
  - Automated meeting prep for 6 meeting types
  - Stakeholder sentiment analysis
  - Strategic initiative linking
  - 80% time reduction in meeting preparation

- **Unified Action Tracker** (`unified_action_tracker_gtd.py`)
  - Complete GTD workflow implementation
  - 7 context tags (@waiting-for, @delegated, @needs-decision, @strategic, @quick-wins, @deep-work, @stakeholder-[name])
  - Priority-based action management
  - Energy-aware task batching

- **Weekly Strategic Review** (`weekly_strategic_review.py`)
  - 90-minute guided GTD review process
  - 6-stage workflow (clear head, review projects, review waiting-for, review goals, review stakeholders, plan week)
  - Automated reminders via LaunchAgents
  - Weekly planning optimization

**Management Tools** (3 tools, 2,150 lines, 3 databases):
- **Stakeholder Intelligence** (`stakeholder_intelligence.py`)
  - CRM-style relationship health monitoring (0-100 scoring)
  - Sentiment analysis across communications
  - 33 stakeholders auto-discovered from 313 emails
  - Color-coded dashboard (🟢🟡🟠🔴)

- **Executive Information Manager** (`executive_information_manager.py`)
  - 5-tier prioritization (critical → noise)
  - Multi-factor scoring (0-100 scale)
  - 15-30 minute morning ritual workflow
  - Energy-aware batch processing

- **Decision Intelligence** (`decision_intelligence.py`)
  - 8 decision templates for different scenarios
  - 6-dimension quality framework (60-point scoring)
  - Outcome tracking and pattern analysis
  - Lessons learned database

**Agent Orchestration Layer** (3 agents, 700 lines):
- **Information Management Orchestrator** - Master coordinator for all 7 tools
- **Stakeholder Intelligence Agent** - Natural language relationship queries
- **Decision Intelligence Agent** - Guided decision capture with quality coaching

**Business Value**:
- **Time Savings**: 7+ hours/week
- **Signal-to-Noise**: 50% improvement
- **ROI**: $50,400/year value vs $2,400 cost = **2,100% ROI**
- **Strategic Time**: Target 50% strategic work (from 20% baseline)

---

### 🧠 Intelligence & RAG Systems

#### 📧 Email RAG System ⭐ **PHASE 80A-80B - COMPLETE**
**GPU-accelerated semantic email search** (100% local, zero cloud):

- **Mail.app Bridge** (`macos_mail_bridge.py`)
  - AppleScript automation for Exchange email access
  - Bypasses Azure AD OAuth restrictions
  - Uses existing Mail.app authentication

- **Email Intelligence** (`mail_intelligence_interface.py`)
  - Intelligent email triage and search
  - Natural language query interface
  - Priority detection and routing

- **Email RAG** (`email_rag_ollama.py`)
  - ChromaDB vector database (768-dim embeddings)
  - Nomic-embed-text model via Ollama
  - **Status**: 313/313 emails indexed
  - **Performance**: 20-44% relevance scores, 0.048s per email
  - **Privacy**: 100% local processing, zero cloud transmission

**Use Cases**:
- "Find emails about the ServiceDesk migration project"
- "Show me conversations with stakeholder X about budget"
- "What did we decide about the cloud architecture?"

#### 💬 Conversation RAG System ⭐ **PHASE 101-102 - PRODUCTION**
**Never lose important conversations**:

- **Conversation RAG** (`conversation_rag_ollama.py`)
  - Semantic search across saved conversations
  - ChromaDB persistent vector database
  - Ollama nomic-embed-text embeddings (100% local)

- **Significance Detection** (`conversation_detector.py`)
  - Automated detection with 83% accuracy
  - Multi-dimensional scoring (topic patterns × depth × engagement)
  - Thresholds: 50+ (save), 35-50 (recommend), 20-35 (consider)

- **Save Helper** (`conversation_save_helper.py`)
  - Auto-extraction of topic, decisions, tags
  - Action item identification
  - <0.1s analysis time

**Storage**: `~/.maia/conversation_rag/` (portable across machines)

**Usage**:
- Manual: `/save-conversation` command
- Automatic: Prompt when significant conversation detected (score > 35)

---

### 🎤 Meeting Intelligence ⭐ **PHASE 83 - PRODUCTION**
**VTT Meeting Transcript Analysis**:

- **VTT Watcher** (`vtt_watcher.py`)
  - Automated monitoring of OneDrive/1-VTT folder
  - macOS LaunchAgent for persistent background service
  - Automatic processing of new meeting recordings

- **Local LLM Processing**
  - CodeLlama 13B via Ollama
  - **Cost savings**: 99.3% vs cloud LLMs
  - 100% privacy (no cloud transmission)

- **FOB Templates** (6 meeting types)
  - Standup, Client, Technical, Planning, Review, One-on-One
  - Meeting type classification
  - Speaker identification
  - Action item extraction
  - Key topics and themes
  - Executive summaries

**Business Value**:
- Standardized meeting formats
- Clear action tracking
- Stakeholder-ready reporting
- Zero manual note-taking

---

### 🔒 Security & Compliance ⭐ **PHASE 78 - PRODUCTION**

**Security Scanner Suite** (October 2025):

- **Local Security Scanner** (`claude/tools/security/local_security_scanner.py`)
  - OSV-Scanner V2.0 integration (dependency vulnerabilities)
  - Bandit integration (Python code security)
  - SARIF output format
  - Automated remediation suggestions

- **Security Hardening Manager** (`claude/tools/security/security_hardening_manager.py`)
  - Lynis integration (system hardening audit)
  - 250+ security checks
  - Compliance scoring
  - Actionable recommendations

- **Weekly Security Scan** (`claude/tools/security/weekly_security_scan.py`)
  - Orchestrated scanning workflow
  - Trend analysis across scans
  - Risk scoring (0-100 scale)
  - Automated alerts for new vulnerabilities

**Setup**: See [SECURITY_SETUP.md](SECURITY_SETUP.md) for installation instructions (Bandit, OSV-Scanner, Lynis)

**Usage**:
```bash
# Quick security scan
python3 claude/tools/security/local_security_scanner.py --scan .

# Weekly comprehensive scan
python3 claude/tools/security/weekly_security_scan.py
```

**Slash Commands**:
- `/security-review` - Comprehensive security analysis
- `/vulnerability-scan` - Vulnerability identification
- `/compliance-check` - Enterprise compliance validation (Essential 8, ISO 27001)
- `/azure-security-audit` - Azure-specific security configurations

**Current Status** (as of 2025-10-22):
- ✅ 0 vulnerabilities detected
- ✅ Risk Level: LOW
- ✅ All tools operational and tested

---

### 🗂️ Productivity Integration

#### Trello Fast Integration ⭐ **PHASE 79 - PRODUCTION**
**Direct API client optimized for terminal usage**:

- **Trello Fast** (`trello_fast.py`)
  - Full CRUD operations (boards, lists, cards, labels, checklists)
  - Zero MCP overhead, instant performance
  - macOS Keychain credential storage (enterprise-grade)
  - Flexible CLI commands preventing parser confusion

**Usage**:
```bash
# List all boards
python3 claude/tools/trello_fast.py boards

# Get specific board
python3 claude/tools/trello_fast.py get-board "Board Name"

# Create card
python3 claude/tools/trello_fast.py create-card "List Name" "Card Title"
```

**Integration**: Personal Assistant Agent orchestration for workflow optimization

#### File Lifecycle Manager ⭐ **PHASE 81 - ANTI-SPRAWL**
**Core file protection system**:

- **File Lifecycle Manager** (`file_lifecycle_manager.py`)
  - 3-tier immutability (absolute/high/medium)
  - Protection rules for 9 core files + critical directories
  - Extension zones (experimental/, personal/, archive/)
  - Git pre-commit hook preventing core file corruption

- **Protection Rules** (`immutable_paths.json`)
  - Prevents accidental deletion/modification of core system files
  - Safe development zones for experimentation
  - Automated archival of deprecated files

**Results**: 517 files organized, 10 naming violations cleaned up

---

## 🤖 Multi-Agent System

### Agent Architecture
Maia uses specialized agents with clear separation of concerns:

**Proper Agent-Tool Separation**:
- **Agents** (Markdown .md files): Orchestrate workflows, natural language interface, response synthesis
- **Tools** (Python .py files): Execute operations, database queries, calculations, API calls

### Available Agents

**Production Agents**:
- **SRE Principal Engineer Agent** - System architecture, deployment, operations
- **UI Systems Agent** - Dashboard creation, interface design, user experience
- **Information Management Orchestrator** - Coordinates 7 information management tools
- **Stakeholder Intelligence Agent** - Relationship management queries
- **Decision Intelligence Agent** - Guided decision capture
- **Personal Assistant Agent** - Workflow optimization, task routing

**Domain Agents**:
- **Security Specialist Agent** - Vulnerability assessment, compliance validation
- **Azure Architect Agent** - Cloud architecture, cost optimization
- **Prompt Engineer Agent** - Advanced prompt design and optimization
- **Company Research Agent** - Deep intelligence gathering

### Agent Orchestration Patterns

**Sequential Chaining**:
```
Agent A → Agent B → Agent C
Research → Analysis → Report Generation
```

**Parallel Processing**:
```
Multiple agents execute simultaneously
Security scan + Performance audit + Compliance check
```

**Conditional Branching**:
```
Smart routing based on intermediate results
IF high_risk THEN escalate_to_security_agent
```

**Feedback Loops**:
```
Quality assurance and iterative improvement
Generate → Review → Refine → Validate
```

---

## 📁 Project Structure

```
maia-team-share/
├── claude/
│   ├── agents/              # Agent definitions (orchestration layer)
│   ├── commands/            # Slash commands (user-facing)
│   ├── context/             # System context and knowledge
│   │   ├── core/           # Core system context
│   │   ├── personal/       # Personal profile templates
│   │   └── knowledge/      # Domain knowledge
│   ├── tools/              # Python tools (execution layer)
│   │   ├── sre/           # SRE and operations tools
│   │   ├── core/          # Core system tools
│   │   └── automation/    # Automation scripts
│   ├── workflows/          # Multi-step workflow definitions
│   └── data/              # Data storage and caches
├── tests/                  # Test suites
├── infrastructure/         # Deployment configurations
├── SYSTEM_STATE.md        # Complete phase history (135+ phases)
├── CLAUDE.md              # System instructions
└── README.md              # This file
```

---

## 🛠️ System Management Commands

**Available Slash Commands**:

**Analysis & Research**:
- `/analyze-project` - Project structure and dependency analysis
- `/research-topic` - Research and summarization with source verification

**Performance & Monitoring**:
- `/performance-analytics` - System performance monitoring
- `/analytics-dashboard` - Real-time system health and metrics
- `/daily-summary` - Comprehensive daily activity summaries

**Configuration**:
- `/setup-mcp-servers` - Model Context Protocol integration
- `/personal-context` - Personal profile context management
- `/optimize-system` - System-wide performance optimization

**Security**:
- `/security-review` - Comprehensive security analysis
- `/vulnerability-scan` - Automated vulnerability identification
- `/compliance-check` - Enterprise compliance validation
- `/azure-security-audit` - Azure-specific security configurations

---

## 💻 Command Execution Patterns

### Natural Language Interface
```
"Analyze the ServiceDesk dashboard project structure"
"Run a security scan and show me any vulnerabilities"
"Search my emails for conversations about the cloud migration"
"What significant conversations should I save from today?"
"Show me my stakeholder relationship health"
```

### Direct Tool Execution
```bash
# Email RAG search
python3 claude/tools/email_rag_ollama.py "ServiceDesk project updates"

# Daily briefing
python3 claude/tools/enhanced_daily_briefing_strategic.py

# Security scan
python3 claude/tools/weekly_security_scan.py

# Conversation save
python3 claude/tools/conversation_save_helper.py
```

### Command Chaining Examples
```bash
# Morning workflow
enhanced_daily_briefing → unified_action_tracker → meeting_context_assembly

# Security assessment
security_scanner → hardening_manager → compliance_check

# Intelligence gathering
email_rag_search → conversation_rag_search → stakeholder_intelligence
```

---

## 🏗️ Creating Custom Commands

### Development Framework
1. **Define Agent Chain** - Multi-stage workflow specification
2. **Implement Data Flow** - Inter-agent communication protocols
3. **Add Error Handling** - Fallback agents and retry mechanisms
4. **Integrate Quality Gates** - Validation and confidence scoring
5. **Enable Performance Tracking** - Success metrics and learning
6. **Document Orchestration** - Usage patterns and integration points
7. **Validate Production** - End-to-end testing and monitoring

### Command Template Structure
```markdown
# Command: [command_name]

## Purpose
[Clear description of what this command does]

## Agent Chain
1. **Primary Agent**: [agent_name]
   - Input: [data_structure]
   - Output: [data_structure]
   - Fallback: [fallback_agent]

2. **Secondary Agent**: [agent_name]
   - Input: [previous_output]
   - Output: [data_structure]
   - Condition: [when_to_execute]

## Usage
```bash
/command-name [arguments]
```

## Quality Assurance
- Input validation protocols
- Output confidence scoring
- Error handling mechanisms
- Performance benchmarks
```

**Storage Location**: `claude/commands/[command_name].md`

---

## 🎨 Customization for Team Members

### Personal Profile Templates
Located in `claude/context/personal/profile.md` and `claude/context/💼_professional/profile.md`:

**What to customize**:
- Your name and contact information
- Your role and company
- Your professional focus areas
- Your working directories

**What to keep**:
- Working philosophy (or adapt to your style)
- Communication preferences
- Technical excellence principles

### Tool Configuration
Many tools support configuration via environment variables in `.env`:

```bash
# Copy example configuration
cp .env.example .env

# Edit with your details
nano .env
```

**Optional configurations**:
- `ANTHROPIC_API_KEY` - For standalone Python tools using Claude API
- `CONFLUENCE_API_TOKEN` - If using Confluence integration
- `TRELLO_API_KEY` - For Trello integration

**Note**: Claude Code itself doesn't need API keys (already authenticated)

---

## 📊 Performance Monitoring

### Context Sharing
- **Shared Memory**: `/tmp/maia_command_context_[command_id].json`
- **Agent Communication**: Structured JSON data flow protocols
- **State Persistence**: Cross-command context preservation
- **Cleanup Management**: Automatic resource management

### Quality Assurance
- **Input Validation**: Comprehensive data validation at each stage
- **Output Quality**: Confidence scoring for all results
- **Chain Integrity**: End-to-end data flow verification
- **User Satisfaction**: Final result validation and feedback collection

### Performance Metrics Example
```json
{
  "command_execution": {
    "command_id": "cmd_20251022_143022",
    "total_duration": "3m 45s",
    "stage_timings": {
      "agent_routing": "0.5s",
      "tool_execution": "2m 30s",
      "response_synthesis": "1m 14.5s"
    },
    "success_rate": 100,
    "confidence_score": 0.95
  }
}
```

---

## 🔍 Integration Points

### Database Systems
- **ChromaDB**: Email RAG, Conversation RAG (vector databases)
- **SQLite**: Performance metrics, stakeholder intelligence, decision tracking
- **PostgreSQL**: ServiceDesk dashboard (Docker container)

### External Services (Optional)
- **Ollama**: Local LLM inference (llama3.1:8b, CodeLlama, nomic-embed-text)
- **Trello**: Task management integration
- **Mail.app**: Email access via AppleScript
- **Docker**: Containerized services (PostgreSQL, Grafana)

### MCP Servers (Model Context Protocol)
- Extensible integration framework
- See `/setup-mcp-servers` for configuration
- Optional: Add custom MCP servers for your tools

---

## 🚨 System State & Phase History

Maia maintains a comprehensive phase history in [SYSTEM_STATE.md](SYSTEM_STATE.md) documenting:
- **135+ development phases** with complete implementation details
- **Problem-solution narratives** for every major feature
- **Metrics and outcomes** for each phase
- **Architecture decisions** and rationale
- **Lessons learned** and best practices

**Recent Key Phases**:
- **Phase 137** (Oct 2025): Personal data cleanup - team-ready repository
- **Phase 136** (Oct 2025): Root directory TDD cleanup - 43% file reduction
- **Phase 115** (Oct 2025): Information Management System - complete GTD ecosystem
- **Phase 101-102** (Oct 2025): Conversation RAG - never lose important conversations
- **Phase 83** (Oct 2025): VTT Meeting Intelligence - automated transcript analysis
- **Phase 80** (Oct 2025): Email RAG - semantic email search with 100% local processing
- **Phase 78** (Oct 2025): Security Scanner Suite - 0 vulnerabilities, production ready

**Smart Context Loading**:
- Intent-aware SYSTEM_STATE.md loading (91.7% token reduction)
- See `claude/tools/sre/smart_context_loader.py`

---

## 🎯 Getting Started Recommendations

### For New Team Members

**Week 1: Core Systems**
1. Complete setup from [TEAM_SETUP_README.md](TEAM_SETUP_README.md)
2. Customize personal profile templates
3. Try `/analyze-project` to understand the codebase
4. Read recent phases in SYSTEM_STATE.md (Phases 115, 136, 137)

**Week 2: Intelligence Systems**
1. Set up Email RAG (Phase 80 documentation)
2. Try Conversation RAG with `/save-conversation`
3. Run daily briefing to see GTD workflow
4. Explore meeting intelligence with VTT files

**Week 3: Security & Monitoring**
1. Run security scan suite
2. Set up performance analytics
3. Configure Trello integration (if using)
4. Review stakeholder intelligence features

**Week 4: Customization**
1. Create your first custom slash command
2. Build a personal automation workflow
3. Integrate with your existing tools
4. Share learnings with team

### For Developers

**Extension Points**:
- Add new agents in `claude/agents/`
- Create slash commands in `claude/commands/`
- Build tools in `claude/tools/`
- Define workflows in `claude/workflows/`

**Testing**:
- TDD protocol mandatory (see Phase 136, 137)
- Test files in `tests/`
- Follow existing patterns for validation

**Documentation**:
- Update SYSTEM_STATE.md for significant changes
- Follow phase documentation template
- Include metrics and outcomes

---

## 📚 Additional Resources

**Documentation**:
- [TEAM_SETUP_README.md](TEAM_SETUP_README.md) - Complete setup guide
- [SHARE_WITH_TEAM.md](SHARE_WITH_TEAM.md) - Repository sharing instructions
- [WSL_RESTORE_GUIDE.md](claude/tools/sre/WSL_RESTORE_GUIDE.md) - Windows/WSL setup
- [SYSTEM_STATE.md](SYSTEM_STATE.md) - Complete phase history

**Key Principles**:
- Zero tolerance for technical debt
- Systematic over reactive approaches
- Quality over speed
- Engineering excellence
- TDD for all development work

**Support**:
- Issues: Use GitHub Issues for bugs/features
- Questions: Check SYSTEM_STATE.md for phase documentation
- Updates: Follow git history for recent changes

---

## 🏆 Design Philosophy

Maia represents a comprehensive personal AI infrastructure built on these principles:

**System Design Over Raw Intelligence**:
- Modular, Unix-like philosophy (do one thing well)
- Composable tools and agents
- Clear separation of concerns

**Privacy & Security First**:
- 100% local processing options (Email RAG, Conversation RAG, LLM inference)
- No cloud transmission of sensitive data
- Enterprise-grade security scanning

**Evidence-Based Development**:
- Comprehensive metrics and tracking
- ROI calculations for all major systems
- Performance monitoring and optimization

**Continuous Improvement**:
- 135+ documented development phases
- Lessons learned captured
- TDD protocol for zero-breakage changes

**Team-Ready**:
- Clean templates for customization
- No personal data in repository
- Professional presentation
- Clear documentation

---

Commands and tools represent the operational layer of Maia's capabilities, transforming complex multi-step workflows into reliable, monitored, and continuously improving processes. The system is production-ready, team-ready, and designed for extensibility.
