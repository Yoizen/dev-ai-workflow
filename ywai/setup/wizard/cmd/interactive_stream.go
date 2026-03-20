package main

import (
	"bytes"
	"io"
	"strings"
	"sync"
)

type streamState struct {
	writer io.Writer
}

type lineStreamWriter struct {
	send func(string)

	mu  sync.Mutex
	buf bytes.Buffer
}

func newLineStreamWriter(send func(string)) io.Writer {
	return &lineStreamWriter{send: send}
}

func (w *lineStreamWriter) Write(p []byte) (int, error) {
	if w == nil {
		return len(p), nil
	}

	w.mu.Lock()
	defer w.mu.Unlock()

	for _, b := range p {
		switch b {
		case '\r':
			w.flushLocked()
		case '\n':
			w.flushLocked()
		default:
			_ = w.buf.WriteByte(b)
		}
	}

	return len(p), nil
}

func (w *lineStreamWriter) flushLocked() {
	if w.buf.Len() == 0 {
		return
	}

	line := strings.TrimRight(w.buf.String(), "\r")
	w.buf.Reset()

	if w.send != nil {
		w.send(line)
	}
}

func (w *lineStreamWriter) Flush() {
	if w == nil {
		return
	}

	w.mu.Lock()
	defer w.mu.Unlock()
	w.flushLocked()
}
