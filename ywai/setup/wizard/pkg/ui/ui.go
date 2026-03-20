package ui

import (
	"fmt"
	"io"
	"os"
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
	Out    io.Writer
}

func NewLogger(silent bool, out ...io.Writer) *Logger {
	writer := io.Writer(os.Stdout)
	if len(out) > 0 && out[0] != nil {
		writer = out[0]
	}

	return &Logger{
		Silent: silent,
		Out:    writer,
	}
}

func (l *Logger) Log(msg string) {
	if l.shouldWrite() {
		fmt.Fprintln(l.out(), msg)
	}
}

func (l *Logger) LogSuccess(msg string) {
	if l.shouldWrite() {
		fmt.Fprintf(l.out(), "%sâœ“%s %s\n", ColorGreen, ColorReset, msg)
	}
}

func (l *Logger) LogWarning(msg string) {
	fmt.Fprintf(l.out(), "%sâš %s %s\n", ColorYellow, ColorReset, msg)
}

func (l *Logger) LogError(msg string) {
	fmt.Fprintf(l.out(), "%sâœ—%s %s\n", ColorRed, ColorReset, msg)
}

func (l *Logger) LogStep(msg string) {
	if l.shouldWrite() {
		fmt.Fprintf(l.out(), "\n%sâ–¶%s %s\n", ColorCyan, ColorReset, msg)
	}
}

func (l *Logger) LogInfo(msg string) {
	if l.shouldWrite() {
		fmt.Fprintf(l.out(), "  %s\n", msg)
	}
}

func (l *Logger) LogSeparator() {
	l.Log(fmt.Sprintf("%sâ”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”%s", ColorCyan, ColorReset))
}

func (l *Logger) out() io.Writer {
	if l != nil && l.Out != nil {
		return l.Out
	}
	return os.Stdout
}

func (l *Logger) shouldWrite() bool {
	if l == nil {
		return false
	}
	if !l.Silent {
		return true
	}
	return l.Out != nil && l.Out != os.Stdout
}
