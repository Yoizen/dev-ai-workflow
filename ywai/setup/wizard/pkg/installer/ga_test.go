package installer

import "testing"

func TestLooksLikeHTMLDocument(t *testing.T) {
	t.Run("rejects real binary payload even if it contains Not Found string", func(t *testing.T) {
		payload := []byte("\x7fELFbinary-data-Not Found-inside-the-binary")
		if looksLikeHTMLDocument(payload) {
			t.Fatal("expected binary payload to be accepted")
		}
	})

	t.Run("detects html payload", func(t *testing.T) {
		payload := []byte("   <!DOCTYPE html><html><body>Not Found</body></html>")
		if !looksLikeHTMLDocument(payload) {
			t.Fatal("expected html payload to be rejected")
		}
	})
}
