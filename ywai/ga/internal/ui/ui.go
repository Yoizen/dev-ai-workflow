package ui

import (
	"fmt"
)

func Info(format string, args ...interface{}) {
	fmt.Printf("ℹ️  "+format+"\n", args...)
}

func Success(format string, args ...interface{}) {
	fmt.Printf("✅ "+format+"\n", args...)
}

func Warning(format string, args ...interface{}) {
	fmt.Printf("⚠️  "+format+"\n", args...)
}

func Error(format string, args ...interface{}) {
	fmt.Printf("❌ "+format+"\n", args...)
}

func PrintBanner(version string) {
	fmt.Println("")
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Printf("  Guardian Agent v%s\n", version)
	fmt.Println("  Provider-agnostic code review using AI")
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println("")
}
