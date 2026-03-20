package installer

import (
	"strings"
	"testing"
)

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

func TestGABuildVersionValue(t *testing.T) {
	tests := []struct {
		name         string
		buildVersion string
		version      string
		want         string
	}{
		{name: "strip v prefix from pinned release", buildVersion: "v6.0.0-beta.7", want: "6.0.0-beta.7"},
		{name: "fallback main becomes dev", version: "main", want: "dev"},
		{name: "plain semver is preserved", version: "6.0.0-beta.7", want: "6.0.0-beta.7"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			inst := &Installer{
				version:      tt.version,
				buildVersion: tt.buildVersion,
				channel:      DEFAULT_CHANNEL,
			}
			if got := inst.gaBuildVersionValue(); got != tt.want {
				t.Fatalf("gaBuildVersionValue() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestGABuildLdflagsUsesExportedVersionVariable(t *testing.T) {
	inst := &Installer{
		version: "v6.0.0-beta.7",
		channel: DEFAULT_CHANNEL,
	}

	flags := inst.gaBuildLdflags("/tmp/ga-source")
	if !strings.Contains(flags, "github.com/yoizen/ga/internal/version.Version=6.0.0-beta.7") {
		t.Fatalf("expected ldflags to set exported Version, got %q", flags)
	}
	if strings.Contains(flags, "internal/version.version=") {
		t.Fatalf("ldflags should not target lowercase version symbol: %q", flags)
	}
}
