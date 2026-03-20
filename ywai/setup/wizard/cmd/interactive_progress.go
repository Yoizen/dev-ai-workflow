package main

import "strings"

func (m setupModel) globalToolsProgressWidth() int {
	width := 28
	if m.width > 0 {
		width = m.width / 3
		if width < 18 {
			width = 18
		}
		if width > 40 {
			width = 40
		}
	}
	return width
}

func progressSegments(current, total, width int) (filled, empty int) {
	if width <= 0 {
		return 0, 0
	}
	if total <= 0 {
		total = 1
	}
	if current < 0 {
		current = 0
	}
	if current > total {
		current = total
	}

	filled = current * width / total
	if filled > width {
		filled = width
	}
	empty = width - filled
	return filled, empty
}

func renderProgressBar(current, total, width int) string {
	filled, empty := progressSegments(current, total, width)
	return "[" +
		successStyle.Render(strings.Repeat("=", filled)) +
		helpStyle.Render(strings.Repeat("-", empty)) +
		"]"
}
