package main

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// Animation helpers driven by the model's animationFrame counter.
//
// The counter ticks every ~140ms while the TUI is active. Helpers use it to
// drive subtle visual motion (color cycles, pulsing glyphs) without relying
// on repeated full re-renders.

// brandPalette is a slowly rotating color palette used by the logo gradient.
var brandPalette = []string{
	"99",  // purple
	"105", // indigo
	"111", // cerulean
	"117", // teal
	"86",  // mint
	"120", // bright teal
	"150", // grassy
	"179", // amber
	"183", // lavender
	"177", // rose
}

// logoGradient returns a color for a given logo line index at the current
// animation frame. Each line's color shifts by one step on every tick so the
// gradient appears to sweep across the logo.
func (m setupModel) logoGradient(lineIndex int) lipgloss.Color {
	if len(brandPalette) == 0 {
		return lipgloss.Color("99")
	}
	idx := (lineIndex + m.animationFrame) % len(brandPalette)
	if idx < 0 {
		idx += len(brandPalette)
	}
	return lipgloss.Color(brandPalette[idx])
}

// pulseGlyph returns one of a small set of glyphs that cycle to hint motion
// next to a "current task" line. Non-ASCII-only to stay terminal-safe.
func (m setupModel) pulseGlyph() string {
	glyphs := []string{"▸", "▹", "▸", "▷"}
	return glyphs[m.animationFrame%len(glyphs)]
}

// pulseLabel returns a label with a soft color cycle so the word itself
// pulses while the spinner animates. Useful for the "Working..." caption.
func (m setupModel) pulseLabel(text string) string {
	palette := []string{"86", "87", "79", "80", "79", "87"}
	color := palette[m.animationFrame%len(palette)]
	return lipgloss.NewStyle().
		Foreground(lipgloss.Color(color)).
		Bold(true).
		Render(text)
}

// renderAnimatedLogo renders the YWAI logo with a per-line animated gradient.
// Lines are passed in top-to-bottom order.
func (m setupModel) renderAnimatedLogo(lines []string) string {
	var out []string
	for i, line := range lines {
		if line == "" {
			out = append(out, line)
			continue
		}
		style := lipgloss.NewStyle().
			Bold(true).
			Foreground(m.logoGradient(i))
		out = append(out, style.Render(line))
	}
	return strings.Join(out, "\n")
}
