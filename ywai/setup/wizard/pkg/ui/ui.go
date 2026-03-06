package ui

import (
	"fmt"
)

const (
	ColorGreen  = "\033[0;32m"
	ColorYellow = "\033[1;33m"
	ColorRed    = "\033[0;31m"
	ColorCyan   = "\033[0;36m"
	ColorReset  = "\033[0m"
)

type Logger struct {
	Silent bool
}

func NewLogger(silent bool) *Logger {
	return &Logger{Silent: silent}
}

func (l *Logger) Log(msg string) {
	if !l.Silent {
		fmt.Println(msg)
	}
}

func (l *Logger) LogSuccess(msg string) {
	if !l.Silent {
		fmt.Printf("%s✓%s %s\n", ColorGreen, ColorReset, msg)
	}
}

func (l *Logger) LogWarning(msg string) {
	fmt.Printf("%s⚠%s %s\n", ColorYellow, ColorReset, msg)
}

func (l *Logger) LogError(msg string) {
	fmt.Printf("%s✗%s %s\n", ColorRed, ColorReset, msg)
}

func (l *Logger) LogStep(msg string) {
	if !l.Silent {
		fmt.Printf("\n%s▶%s %s\n", ColorCyan, ColorReset, msg)
	}
}

func (l *Logger) LogInfo(msg string) {
	if !l.Silent {
		fmt.Printf("  %s\n", msg)
	}
}

func (l *Logger) LogSeparator() {
	l.Log(fmt.Sprintf("%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s", ColorCyan, ColorReset))
}
