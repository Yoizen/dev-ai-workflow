# ============================================================================
# Central configuration — repo, release, and channel settings (PowerShell)
# ============================================================================
# All values are overrideable via environment variables.
# Dot-source this file instead of hardcoding URLs in other scripts.
# ============================================================================

# ── Repository ────────────────────────────────────────────────────────────────

$YWAI_REPO     = if ($env:YWAI_REPO)     { $env:YWAI_REPO }     else { "Yoizen/dev-ai-workflow" }
$YWAI_REPO_URL = if ($env:YWAI_REPO_URL) { $env:YWAI_REPO_URL } else { "https://github.com/$YWAI_REPO.git" }
$YWAI_RAW_URL  = if ($env:YWAI_RAW_URL)  { $env:YWAI_RAW_URL }  else { "https://raw.githubusercontent.com/$YWAI_REPO" }
$YWAI_API_URL  = "https://api.github.com/repos/$YWAI_REPO"

# ── Release channel ───────────────────────────────────────────────────────────
# stable  → latest non-prerelease GitHub Release (default)
# latest  → absolute latest GitHub Release (may be pre-release)
# <tag>   → exact tag, e.g. v1.2.0

$YWAI_CHANNEL = if ($env:YWAI_CHANNEL) { $env:YWAI_CHANNEL } else { "stable" }

# Pinned version — overrides channel when set
$YWAI_VERSION = if ($env:YWAI_VERSION) { $env:YWAI_VERSION } else { "" }

# Branch used as fallback when no releases exist yet or API is unreachable
$YWAI_FALLBACK_BRANCH = if ($env:YWAI_FALLBACK_BRANCH) {
    $env:YWAI_FALLBACK_BRANCH
} elseif ($env:DEV_AI_WORKFLOW_REF) {
    $env:DEV_AI_WORKFLOW_REF
} else {
    "main"
}

# ── GA local install dir ──────────────────────────────────────────────────────

$GA_REPO = $YWAI_REPO_URL
$GA_DIR  = if ($env:GA_DIR) { $env:GA_DIR } else { "$env:USERPROFILE\.local\share\yoizen\dev-ai-workflow" }

# ── Release resolution ────────────────────────────────────────────────────────

function Get-YwaiStableRelease {
    try {
        $releases = Invoke-RestMethod -Uri "$YWAI_API_URL/releases" -ErrorAction Stop -TimeoutSec 5
        $stable = $releases | Where-Object { -not $_.prerelease } | Select-Object -First 1
        if ($stable) { return $stable.tag_name }
    } catch {}
    return ""
}

function Get-YwaiLatestRelease {
    try {
        $release = Invoke-RestMethod -Uri "$YWAI_API_URL/releases/latest" -ErrorAction Stop -TimeoutSec 5
        return $release.tag_name
    } catch {}
    return ""
}

function Resolve-YwaiRef {
    param([string]$Version = $YWAI_VERSION, [string]$Channel = $YWAI_CHANNEL)

    # Explicit version pinned (not a channel keyword)
    if ($Version -and $Version -ne "stable" -and $Version -ne "latest") {
        return $Version
    }

    $effectiveChannel = if ($Version) { $Version } else { $Channel }
    $tag = ""

    switch ($effectiveChannel) {
        "stable" { $tag = Get-YwaiStableRelease }
        "latest" { $tag = Get-YwaiLatestRelease }
    }

    if ($tag) { return $tag }
    return $YWAI_FALLBACK_BRANCH
}

function Get-YwaiRefDescription {
    $ref = Resolve-YwaiRef
    if ($ref -eq $YWAI_FALLBACK_BRANCH) {
        return "branch $ref (no releases found)"
    }
    return "release $ref"
}
