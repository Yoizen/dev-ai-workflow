//go:build windows

package main

import "syscall"

// Windows consoles default to an OEM/Latin-1 code page (e.g. 437 or 1252).
// The setup wizard emits UTF-8 (✓, ▶, ✗, spinner glyphs, etc.) and without
// switching the console to CP 65001 those bytes render as garbled "â", "œ"
// sequences in the log box. This init() is a one-shot at program startup
// and is a no-op on terminals that already default to UTF-8
// (Windows Terminal, Warp, WezTerm, VS Code integrated terminal).
//
// SetConsoleOutputCP and SetConsoleCP are idempotent; if the call fails we
// keep the original code page (this happens when stdout isn't attached to a
// real console, e.g. in CI or when output is piped).
func init() {
	const cpUTF8 = 65001

	kernel32 := syscall.NewLazyDLL("kernel32.dll")
	setConsoleOutputCP := kernel32.NewProc("SetConsoleOutputCP")
	setConsoleCP := kernel32.NewProc("SetConsoleCP")

	_, _, _ = setConsoleOutputCP.Call(uintptr(cpUTF8))
	_, _, _ = setConsoleCP.Call(uintptr(cpUTF8))
}
