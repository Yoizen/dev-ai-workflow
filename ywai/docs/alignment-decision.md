# Alignment Decision: dev-ai-workflow vs gentle-ai

## Overview

This document evaluates the alignment between `dev-ai-workflow` and `gentle-ai` (formerly Agent Teams Lite) to determine the optimal path forward.

## Feature Comparison

### Unique to dev-ai-workflow

1. **Technology-Specific Skills**
   - TypeScript
   - React 19
   - Angular (core, forms, performance, architecture)
   - .NET / C#
   - Python
   - DevOps (Azure Pipelines, Helm charts, Kubernetes)
   - Biome (linter/formatter)

2. **Project Type System**
   - `types.json` with per-type configuration
   - Types: generic, nest, nest-angular, nest-react, python, dotnet, qa-playwright, devops
   - Per-type global agents selection
   - Per-type skills and extensions

3. **Project Extensions**
   - Extension system in `ywai/extensions/`
   - Install-steps for global-agents, engram-setup
   - Configurable via project types

### Unique to gentle-ai

1. **Go Binary Architecture**
   - Native Go binary for setup wizard
   - Cross-platform compilation
   - Better performance and portability

2. **SDD Profiles**
   - Per-phase model assignment
   - CLI for profile management (list, create, set, activate, delete)
   - Configurable model selection per SDD phase

3. **Robust Auto-Update**
   - `--self-update` command
   - Periodic update checks (configurable interval)
   - Auto-update via environment variable
   - GitHub API integration for version resolution

4. **Broader Agent Support**
   - 9 AI assistants supported
   - Better integration with various AI tools

5. **Installation Methods**
   - `brew`, `scoop`, `go install @latest`
   - PowerShell scripts
   - More flexible installation options

### Common Features

- SDD (Spec-Driven Development) workflow
- Engram integration for persistent memory
- Global agents system
- Skills-based architecture
- AGENTS.md documentation
- MCP (Multi-Agent Collaboration Protocol) support

## Analysis

### Strengths of dev-ai-workflow

1. **Deep Technology Expertise**
   - Curated skills for specific frameworks and languages
   - Production-ready configurations
   - Industry best practices embedded

2. **Project Context Awareness**
   - Per-type configuration system
   - Tailored agent selection per project type
   - Extension system for project-specific needs

3. **Focused Scope**
   - Optimized for enterprise development workflows
   - Specific technology stacks (NestJS, Angular, .NET, Python)
   - DevOps integration

### Strengths of gentle-ai

1. **Better Infrastructure**
   - Go binary for cross-platform support
   - Robust auto-update mechanism
   - More installation options

2. **Flexibility**
   - SDD Profiles for cost optimization
   - Broader agent support
   - More generic (less opinionated)

3. **Community Momentum**
   - Supersedes Agent Teams Lite
   - Active development
   - Broader user base

## Options

### Option A: Migrate to gentle-ai

**Description:** Contribute dev-ai-workflow's technology-specific skills to gentle-ai and deprecate dev-ai-workflow.

**Pros:**
- Single codebase to maintain
- Access to better infrastructure
- Larger community
- Better auto-update mechanism

**Cons:**
- Loss of project-type system
- Technology-specific skills may not fit gentle-ai's generic model
- Less control over direction
- Migration effort significant

**Effort:** High
**Timeline:** 3-6 months

### Option B: Fork gentle-ai

**Description:** Fork gentle-ai and add dev-ai-workflow's unique features (project types, tech-specific skills).

**Pros:**
- Best of both worlds: better infrastructure + unique features
- Maintain control over project-type system
- Can contribute upstream improvements

**Cons:**
- Fork maintenance burden
- Potential divergence from upstream
- Need to track upstream changes
- More complex merge process

**Effort:** Medium-High
**Timeline:** 2-4 months

### Option C: Maintain Divergence (Recommended)

**Description:** Continue independent development, implement missing features from gentle-ai (auto-update, SDD profiles, broader agent support).

**Pros:**
- Full control over project direction
- Project-type system preserved
- Technology-specific skills remain focused
- Can selectively adopt gentle-ai features

**Cons:**
- Duplicate infrastructure effort
- Smaller user base
- More maintenance burden

**Effort:** Medium (already in progress)
**Timeline:** 1-2 months (to implement missing features)

**Current Status:**
- ✅ Auto-update mechanism implemented
- ✅ SDD Profiles implemented
- ✅ Broader agent support implemented (Gemini, Cursor)
- ✅ Global agents version control implemented

## Recommendation

**Option C: Maintain Divergence with Selective Adoption**

**Rationale:**

1. **Unique Value Proposition:** dev-ai-workflow's project-type system and technology-specific skills provide unique value not available in gentle-ai. These features are core to the project's identity and target audience (enterprise development teams).

2. **Implementation Progress:** The key differentiating features from gentle-ai (auto-update, SDD profiles, agent support) have already been implemented in dev-ai-workflow. The gap has been narrowed significantly.

3. **Target Audience Difference:** gentle-ai targets a broader audience with generic needs, while dev-ai-workflow focuses on specific technology stacks (NestJS, Angular, .NET, Python) with enterprise-grade configurations.

4. **Maintainability:** The project-type system and technology-specific skills would require significant refactoring to fit gentle-ai's architecture, making migration expensive with uncertain benefits.

## Next Steps

1. **Continue Independent Development**
   - Maintain project-type system
   - Expand technology-specific skills
   - Improve DevOps integration

2. **Monitor gentle-ai**
   - Track upstream improvements
   - Selectively adopt useful features
   - Consider future alignment if architectures converge

3. **Enhance Documentation**
   - Clearly articulate unique value proposition
   - Document differences from gentle-ai
   - Provide migration guides for users considering gentle-ai

4. **Community Engagement**
   - Share technology-specific skills with community
   - Contribute to gentle-ai where appropriate (e.g., skill patterns)
   - Maintain open communication with gentle-ai maintainers

## Conclusion

dev-ai-workflow should maintain its independent development path while selectively adopting best practices from gentle-ai. The project-type system and technology-specific skills provide unique value that would be lost in migration or forking. The implementation of auto-update, SDD profiles, and broader agent support has narrowed the feature gap, making independent development the most viable option.
