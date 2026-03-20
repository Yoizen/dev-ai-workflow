package main

import "testing"

func TestProgressSegments(t *testing.T) {
	tests := []struct {
		name       string
		current    int
		total      int
		width      int
		wantFilled int
		wantEmpty  int
	}{
		{name: "empty", current: 0, total: 5, width: 10, wantFilled: 0, wantEmpty: 10},
		{name: "mid", current: 2, total: 5, width: 10, wantFilled: 4, wantEmpty: 6},
		{name: "complete", current: 5, total: 5, width: 10, wantFilled: 10, wantEmpty: 0},
		{name: "clamped", current: 9, total: 5, width: 10, wantFilled: 10, wantEmpty: 0},
		{name: "zero total", current: 1, total: 0, width: 8, wantFilled: 8, wantEmpty: 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			filled, empty := progressSegments(tt.current, tt.total, tt.width)
			if filled != tt.wantFilled || empty != tt.wantEmpty {
				t.Fatalf("progressSegments(%d, %d, %d) = (%d, %d), want (%d, %d)",
					tt.current, tt.total, tt.width, filled, empty, tt.wantFilled, tt.wantEmpty)
			}
		})
	}
}
