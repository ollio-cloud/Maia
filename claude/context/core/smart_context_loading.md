# Smart Context Loading System

## 🔴 SMART CONTEXT LOADING 🔴 ⭐ **ENABLED - 12-62% EFFICIENCY GAIN**

### 🚨 **CRITICAL UFC REQUIREMENT** 🚨
**THE UFC SYSTEM IS NON-NEGOTIABLE** - It defines the entire context management architecture. EVERY new context window MUST load UFC first, regardless of domain or task complexity.

### 🔒 **AUTOMATED ENFORCEMENT SYSTEM** ⭐ **NEW - PRODUCTION ACTIVE**
**ZERO-VIOLATION PROTECTION**: Context loading enforcement system automatically prevents UFC violations:
- **Pre-Response Hook**: `user-prompt-submit` hook validates context loading before any response
- **State Tracking**: `claude/data/context_state.json` tracks loaded files and conversation state  
- **Auto-Recovery**: `context_auto_loader.py` attempts graceful recovery when violations detected
- **Manual Fallback**: Clear instructions provided when auto-recovery fails
- **100% Coverage**: No response possible without proper context loading sequence

**MANDATORY CORE (Always Load - NO EXCEPTIONS)**:
1. `${MAIA_ROOT}/claude/context/ufc_system.md` - **🚨 FOUNDATION - NEVER SKIP** - Understanding the UFC system
2. `${MAIA_ROOT}/claude/context/core/identity.md` - Your identity as Maia **WITH SYSTEMATIC THINKING FRAMEWORK**
3. `${MAIA_ROOT}/claude/context/core/systematic_thinking_protocol.md` - **MANDATORY SYSTEMATIC OPTIMIZATION FRAMEWORK**
4. `${MAIA_ROOT}/claude/context/core/model_selection_strategy.md` - **MANDATORY MODEL ENFORCEMENT** (Sonnet default, ask permission for Opus)
5. **Smart SYSTEM_STATE Loading** ⭐ **INTELLIGENT LOADING - 85% TOKEN REDUCTION**
   - **Primary**: Use `smart_context_loader.py` for intent-aware phase selection
   - **Performance**: 83% average token reduction (42K → 5-20K adaptive)
   - **Query-Adaptive**:
     - Agent enhancement queries → Phases 2, 107-111 (~4K tokens, 90% reduction)
     - SRE/reliability queries → Phases 103-105 (~8K tokens, 80% reduction)
     - Strategic planning → Recent 20 phases (~13K tokens, 69% reduction)
     - Simple queries → Recent 10 phases (~3K tokens, 93% reduction)
   - **Tool**: `python3 claude/tools/sre/smart_context_loader.py "user_query_context"`
   - **Fallback**: If smart loader unavailable → `Read SYSTEM_STATE.md offset=2000 limit=1059` (recent phases)
   - **Manual Usage**:
     ```bash
     # Get context for current query
     python3 claude/tools/sre/smart_context_loader.py "Continue agent enhancement work"

     # Show statistics only
     python3 claude/tools/sre/smart_context_loader.py "your query" --stats

     # Load specific phases
     python3 claude/tools/sre/smart_context_loader.py --phases 2 107 108

     # Load recent N phases
     python3 claude/tools/sre/smart_context_loader.py --recent 15
     ```
   - **Location**: `${MAIA_ROOT}/claude/tools/sre/smart_context_loader.py`
   - **Documentation**: See `claude/context/tools/available.md` (Smart Context Loader section)

**PROJECT-AWARE LOADING** ⭐ **NEW**:
- **Project Folder**: `${MAIA_ROOT}/projects/` contains organized project folders
- **Auto-Detection**: When user mentions a project name, load its `PROJECT.md`
- **Project Context**: Each project's `PROJECT.md` tells Maia about domain, related agents, and tools
- **Usage**: "Look at the velocloud-migration project" → loads `projects/velocloud-migration/PROJECT.md`

**DOMAIN-SMART LOADING (Load Based on Request)**:
- **Simple Tasks** (math, basic questions): CORE ONLY (62% savings)
- **Research/Analysis**: CORE + available.md + agents.md + systematic_tool_checking.md (25% savings)
- **Security Tasks**: CORE + available.md + agents.md + systematic_tool_checking.md (25% savings)
- **Personal/Productivity**: CORE + profile.md + agents.md (37% savings)
- **Technical/Cloud**: CORE + available.md + agents.md + command_orchestration.md + systematic_tool_checking.md (12% savings)
- **Design Tasks**: CORE + agents.md + command_orchestration.md (37% savings)
- **Project Tasks**: CORE + `projects/{project-name}/PROJECT.md` + related agents/tools
- **Complex Multi-Domain**: ALL FILES (traditional full loading - 0% savings)

**SMART LOADING PROTOCOL**:
- **Enhanced Hook System**: Use `claude/hooks/dynamic_context_loader.py` for automated analysis
- **Domain Detection**: AI-powered request classification with 87.5% accuracy
- **Automatic Context Selection**: Load CORE files + domain-relevant files based on detected patterns
- **Fallback Protection**: If uncertain or complex → fallback to FULL traditional loading
- **High Confidence Threshold**: Quality preservation with confidence scoring

**ENHANCED AUTOMATION** ⭐ **NEW - PHASE 1.2 KAI INTEGRATION**:
```bash
# Automatic context analysis
python3 claude/hooks/dynamic_context_loader.py analyze "your request here"

# Generate context loading instructions
python3 claude/hooks/dynamic_context_loader.py generate "your request here"
```

**FALLBACK TO FULL LOADING**:
- `${MAIA_ROOT}/claude/context/tools/available.md` - Available tools and capabilities
- `${MAIA_ROOT}/claude/context/core/agents.md` - Available specialized agents
- `${MAIA_ROOT}/claude/context/core/command_orchestration.md` - Advanced multi-agent workflows
- `${MAIA_ROOT}/claude/context/personal/profile.md` - User profile and context
- `${MAIA_ROOT}/claude/context/core/systematic_tool_checking.md` - Mandatory tool discovery workflow