package globalagents

import (
	"fmt"
	"strings"
)

// Target identifies the destination AI assistant for a generated agent file.
type Target int

const (
	TargetOpenCode Target = iota
	TargetCopilotAgent
	TargetCopilotPrompt
	TargetGemini
	TargetCursor
	TargetClaude
)

// RenderInput bundles everything needed to render a single agent file.
type RenderInput struct {
	AgentName     string
	ProjectType   string
	Target        Target
	Template      string // Raw content of templates/<agent>.md (may include frontmatter)
	Bundle        []string
	SkillsTriggers map[string]string // skill -> "a | b | c" (may be empty per skill)
}

// Render produces the final file content for a target platform.
// Ordering: target-specific frontmatter -> heading -> project type note ->
// base directives (stripped of template frontmatter) -> Skills bundle (global)
// -> Skills invoke -> SDD quick commands (if bundle includes any sdd-*) ->
// DevOps trigger keywords (if bundle includes devops).
func Render(in RenderInput) []byte {
	var b strings.Builder

	b.WriteString(frontmatter(in))
	b.WriteString(fmt.Sprintf("# %s\n\n", in.AgentName))
	b.WriteString(fmt.Sprintf("Project type scope: %s\n", in.ProjectType))

	body := stripFrontmatter(in.Template)
	body = strings.TrimSpace(body)
	if body != "" {
		b.WriteString("\n## Base directives (from extensions)\n")
		b.WriteString(body)
		if !strings.HasSuffix(body, "\n") {
			b.WriteString("\n")
		}
	} else {
		b.WriteString("\n## Base directives (from extensions)\n")
		b.WriteString("Template not found for this agent. Use focused, minimal, and safe defaults.\n")
	}

	if len(in.Bundle) > 0 {
		b.WriteString("\n## Skills bundle (global)\n")
		for _, s := range in.Bundle {
			b.WriteString(fmt.Sprintf("- `%s`\n", s))
		}

		b.WriteString("\n## Skills invoke\n")
		for _, s := range in.Bundle {
			trigger := in.SkillsTriggers[s]
			if trigger != "" {
				b.WriteString(fmt.Sprintf("- Use `%s` when tasks match: %s.\n", s, trigger))
			} else {
				b.WriteString(fmt.Sprintf("- Use `%s` when its domain is required.\n", s))
			}
		}
	}

	if hasAnySDDSkill(in.Bundle) {
		b.WriteString("\n## SDD quick commands\n")
		b.WriteString("- `/sdd:new <change-name>`\n")
		b.WriteString("- `/sdd:ff <change-name>`\n")
		b.WriteString("- `/sdd:apply`\n")
		b.WriteString("- `/sdd:verify`\n")
		b.WriteString("- `/sdd:archive`\n")
	}

	if contains(in.Bundle, "devops") {
		b.WriteString("\n## DevOps trigger keywords\n")
		for _, k := range []string{"pipeline", "azure pipelines", "helm", "docker", "devops", "kubernetes", "k8s", "deploy", "ci/cd"} {
			b.WriteString(fmt.Sprintf("- %s\n", k))
		}
	}

	return []byte(b.String())
}

func frontmatter(in RenderInput) string {
	switch in.Target {
	case TargetCopilotPrompt:
		return fmt.Sprintf(
			"---\nname: %s\ndescription: Global %s instructions for %s projects\napplyTo: \"**\"\n---\n\n",
			in.AgentName, in.AgentName, in.ProjectType,
		)
	case TargetCopilotAgent:
		return fmt.Sprintf(
			"---\nname: %s\ndescription: Global %s agent for %s projects\n---\n\n",
			in.AgentName, in.AgentName, in.ProjectType,
		)
	case TargetOpenCode, TargetGemini, TargetCursor, TargetClaude:
		return fmt.Sprintf(
			"---\ndescription: %s global agent for %s projects\n---\n\n",
			in.AgentName, in.ProjectType,
		)
	}
	return ""
}

// stripFrontmatter removes a leading YAML frontmatter block (--- ... ---).
func stripFrontmatter(raw string) string {
	if !strings.HasPrefix(raw, "---") {
		return raw
	}
	rest := raw[3:]
	// Find next line with exactly "---".
	idx := strings.Index(rest, "\n---")
	if idx < 0 {
		return raw
	}
	// Advance past the closing "---" and subsequent newline if present.
	after := rest[idx+4:]
	after = strings.TrimPrefix(after, "\n")
	return after
}

func hasAnySDDSkill(bundle []string) bool {
	for _, s := range bundle {
		if strings.HasPrefix(s, "sdd-") {
			return true
		}
	}
	return false
}

func contains(bundle []string, name string) bool {
	for _, s := range bundle {
		if s == name {
			return true
		}
	}
	return false
}
