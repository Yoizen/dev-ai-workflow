package ui

import (
	"testing"
)

func TestLogger_Log(t *testing.T) {
	logger := NewLogger(false)
	logger.Log("test message")
	// This test just ensures no panic occurs
	t.Log("Log method works without panic")
	
	// Test silent mode
	silentLogger := NewLogger(true)
	silentLogger.Log("silent message")
	// Should not output anything
}

func TestLogger_LogSuccess(t *testing.T) {
	logger := NewLogger(false)
	logger.LogSuccess("success message")
	// Just ensure no panic
}

func TestLogger_LogWarning(t *testing.T) {
	logger := NewLogger(false)
	logger.LogWarning("warning message")
	// Just ensure no panic
}

func TestLogger_LogError(t *testing.T) {
	logger := NewLogger(false)
	logger.LogError("error message")
	// Just ensure no panic
}

func TestLogger_LogStep(t *testing.T) {
	logger := NewLogger(false)
	logger.LogStep("step message")
	// Just ensure no panic
}

func TestLogger_LogInfo(t *testing.T) {
	logger := NewLogger(false)
	logger.LogInfo("info message")
	// Just ensure no panic
}

func TestNewLogger(t *testing.T) {
	logger := NewLogger(true)
	if !logger.Silent {
		t.Error("Expected silent logger")
	}
	
	logger = NewLogger(false)
	if logger.Silent {
		t.Error("Expected non-silent logger")
	}
}

func TestLogger_LogSeparator(t *testing.T) {
	logger := NewLogger(false)
	logger.LogSeparator()
	// Just ensure no panic
}
