class Ywai < Formula
  desc "AI Development Workflow - SDD Orchestrator for OpenCode/Copilot"
  homepage "https://github.com/Yoizen/dev-ai-workflow"
  version "6.0.0-beta.2"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/Yoizen/dev-ai-workflow/releases/download/v6.0.0-beta.2/setup-wizard-darwin-arm64"
      sha256 :no_check
    else
      url "https://github.com/Yoizen/dev-ai-workflow/releases/download/v6.0.0-beta.2/setup-wizard-darwin-amd64"
      sha256 :no_check
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/Yoizen/dev-ai-workflow/releases/download/v6.0.0-beta.2/setup-wizard-linux-arm64"
      sha256 :no_check
    else
      url "https://github.com/Yoizen/dev-ai-workflow/releases/download/v6.0.0-beta.2/setup-wizard-linux-amd64"
      sha256 :no_check
    end
  end

  def install
    bin.install Dir["setup-wizard-*"][0] => "ywai"
  end

  test do
    system "#{bin}/ywai", "--help"
  end
end
