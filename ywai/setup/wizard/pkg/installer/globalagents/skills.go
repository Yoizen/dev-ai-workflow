package globalagents

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// AutoInvokePatterns extracts the auto_invoke values from a skill's SKILL.md
// frontmatter. Replaces the bash+python implementation of
// skill_auto_invoke_patterns in ywai/skills/setup.sh.
//
// Supports:
//
//	auto_invoke: ["a", "b"]
//	auto_invoke:
//	  - a
//	  - b
//	auto_invoke: a
func AutoInvokePatterns(skillsDir, skillName string) []string {
	if skillsDir == "" || skillName == "" {
		return nil
	}

	path := filepath.Join(skillsDir, filepath.FromSlash(skillName), "SKILL.md")
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()

	// Only parse the frontmatter (first --- block).
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)

	inFrontmatter := false
	firstLine := true
	lines := make([]string, 0, 32)

	for scanner.Scan() {
		line := scanner.Text()
		if firstLine {
			firstLine = false
			if strings.TrimSpace(line) == "---" {
				inFrontmatter = true
				continue
			}
			// No frontmatter opener: try to read up to a "---" marker treated
			// as a frontmatter terminator in plain-top docs.
			lines = append(lines, line)
			continue
		}
		if inFrontmatter && strings.TrimSpace(line) == "---" {
			break
		}
		if !inFrontmatter && strings.TrimSpace(line) == "---" {
			break
		}
		lines = append(lines, line)
	}

	return parseAutoInvoke(lines)
}

var inlineListRE = regexp.MustCompile(`^\s*auto_invoke\s*:\s*\[(.*)\]\s*$`)
var scalarRE = regexp.MustCompile(`^\s*auto_invoke\s*:\s*(.+?)\s*$`)
var itemRE = regexp.MustCompile(`^\s*-\s+(.+?)\s*$`)

func parseAutoInvoke(lines []string) []string {
	for i, line := range lines {
		if m := inlineListRE.FindStringSubmatch(line); m != nil {
			return splitInlineList(m[1])
		}
		if strings.HasPrefix(strings.TrimSpace(line), "auto_invoke:") {
			rest := strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(line), "auto_invoke:"))
			if rest != "" {
				// inline list handled above; try scalar
				if m := scalarRE.FindStringSubmatch(line); m != nil {
					return []string{strings.Trim(m[1], `"'`)}
				}
			}
			// Multi-line list below.
			out := []string{}
			for j := i + 1; j < len(lines); j++ {
				cur := lines[j]
				if strings.TrimSpace(cur) == "" {
					continue
				}
				if m := itemRE.FindStringSubmatch(cur); m != nil {
					out = append(out, strings.Trim(m[1], `"'`))
					continue
				}
				break
			}
			return dedupe(out)
		}
	}
	return nil
}

func splitInlineList(raw string) []string {
	parts := strings.Split(raw, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		p = strings.Trim(p, `"'`)
		if p != "" {
			out = append(out, p)
		}
	}
	return dedupe(out)
}

func dedupe(items []string) []string {
	seen := make(map[string]struct{}, len(items))
	out := make([]string, 0, len(items))
	for _, v := range items {
		if _, ok := seen[v]; ok {
			continue
		}
		seen[v] = struct{}{}
		out = append(out, v)
	}
	return out
}

// joinTriggers formats up to 3 auto_invoke patterns as "a | b | c".
// Matches the truncation of the legacy bash implementation.
func joinTriggers(patterns []string) string {
	if len(patterns) == 0 {
		return ""
	}
	limit := 3
	if len(patterns) < limit {
		limit = len(patterns)
	}
	return strings.Join(patterns[:limit], " | ")
}

// _ keeps fmt import referenced when future logging is added.
var _ = fmt.Sprintf
