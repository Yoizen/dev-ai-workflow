#!/usr/bin/env bash
# ============================================================================
# Central configuration — repo, release, and channel settings
# ============================================================================
# All values are overrideable via environment variables.
# Source this file instead of hardcoding URLs in other scripts.
# ============================================================================

# ── Repository ────────────────────────────────────────────────────────────────

YWAI_REPO="${YWAI_REPO:-Yoizen/dev-ai-workflow}"
YWAI_REPO_URL="${YWAI_REPO_URL:-https://github.com/${YWAI_REPO}.git}"
YWAI_RAW_URL="${YWAI_RAW_URL:-https://raw.githubusercontent.com/${YWAI_REPO}}"
YWAI_API_URL="https://api.github.com/repos/${YWAI_REPO}"

# ── Release channel ───────────────────────────────────────────────────────────
# stable  → latest non-prerelease GitHub Release (default)
# latest  → absolute latest GitHub Release (may be pre-release)
# <tag>   → exact tag, e.g. v1.2.0

YWAI_CHANNEL="${YWAI_CHANNEL:-stable}"

# Pinned version — overrides channel when set (e.g. v1.0.0 or "latest"/"stable")
YWAI_VERSION="${YWAI_VERSION:-}"

# Branch used as fallback when no releases exist yet or API is unreachable
YWAI_FALLBACK_BRANCH="${YWAI_FALLBACK_BRANCH:-${DEV_AI_WORKFLOW_REF:-main}}"

# ── GA local install dir ──────────────────────────────────────────────────────

GA_REPO="$YWAI_REPO_URL"  # shellcheck disable=SC2034
GA_DIR="${GA_DIR:-$HOME/.local/share/yoizen/dev-ai-workflow}"

# ── Release resolution ────────────────────────────────────────────────────────

# Fetch the latest stable release tag from GitHub API.
# Returns empty string on failure (caller should fallback to branch).
_ywai_fetch_stable_release() {
  local tag
  tag=$(curl -fsSL --connect-timeout 5 "${YWAI_API_URL}/releases" 2>/dev/null \
    | grep -E '"tag_name"|"prerelease"' \
    | paste - - \
    | grep '"prerelease": *false' \
    | grep -o '"tag_name": *"[^"]*"' \
    | head -1 \
    | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
  echo "${tag:-}"
}

# Fetch the absolute latest release tag (may be pre-release).
_ywai_fetch_latest_release() {
  local tag
  tag=$(curl -fsSL --connect-timeout 5 "${YWAI_API_URL}/releases/latest" 2>/dev/null \
    | grep '"tag_name"' \
    | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' \
    | head -1)
  echo "${tag:-}"
}

# Resolve the ref (tag or branch) to use for cloning/bootstrap.
# Priority: YWAI_VERSION env → channel → fallback branch
# Prints the resolved ref to stdout.
ywai_resolve_ref() {
  local version="${YWAI_VERSION:-}"

  # Explicit version pinned
  if [[ -n "$version" && "$version" != "stable" && "$version" != "latest" ]]; then
    echo "$version"
    return 0
  fi

  local channel="${version:-$YWAI_CHANNEL}"
  local tag=""

  case "$channel" in
    stable)
      tag="$(_ywai_fetch_stable_release)"
      ;;
    latest)
      tag="$(_ywai_fetch_latest_release)"
      ;;
  esac

  if [[ -n "$tag" ]]; then
    echo "$tag"
  else
    echo "$YWAI_FALLBACK_BRANCH"
  fi
}

# Print a one-liner summary of what ref will be used (for display)
ywai_ref_description() {
  local ref; ref="$(ywai_resolve_ref)"
  if [[ "$ref" == "$YWAI_FALLBACK_BRANCH" ]]; then
    echo "branch ${ref} (no releases found)"
  else
    echo "release ${ref}"
  fi
}
