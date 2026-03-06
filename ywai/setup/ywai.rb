class Ywai < Formula
  desc "AI Development Workflow - SDD Orchestrator for OpenCode/Copilot"
  homepage "https://github.com/Yoizen/dev-ai-workflow"
  url "https://github.com/Yoizen/dev-ai-workflow/releases/download/v5.0.0/setup-wizard"
  version "5.0.0"
  sha256 "TODO: Add SHA256 after first release"
  license "MIT"

  depends_on "git"

  def install
    bin.install "setup-wizard" => "ywai"
  end

  test do
    system "#{bin}/ywai", "--version"
  end
end
