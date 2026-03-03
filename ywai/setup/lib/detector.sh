#!/usr/bin/env bash
# Component detection: GA, SDD, VS Code extensions, prerequisites

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ui.sh
source "$_LIB_DIR/ui.sh"
# shellcheck source=config.sh
source "$_LIB_DIR/config.sh"

GA_API_URL="$YWAI_API_URL"

# ── Version helpers ───────────────────────────────────────────────────────────

# Read "version" field from a package.json file
get_version() {
  local pkg_file="$1"
  [[ -f "$pkg_file" ]] || return 0
  grep -o '"version": *"[^"]*"' "$pkg_file" | head -1 | cut -d'"' -f4
}

# Fetch latest published tag from GitHub (returns "unknown" on failure)
# Respects YWAI_CHANNEL: stable (default) returns latest non-prerelease.
get_latest_ga_version() {
  local tag
  tag="$(_ywai_fetch_stable_release)"

  if [[ -z "$tag" ]]; then
    tag="$(_ywai_fetch_latest_release)"
  fi

  if [[ -z "$tag" ]]; then
    tag=$(curl -fsSL --connect-timeout 5 "${GA_API_URL}/tags" 2>/dev/null \
      | grep '"name"' \
      | sed -E 's/.*"name": *"v?([^"]+)".*/\1/' \
      | head -1)
  fi

  echo "${tag:-unknown}"
}

# Return installed GA version (empty string when not installed)
get_installed_ga_version() {
  command_exists ga || return 0
  ga version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9x]+' | head -1
}

# ── Component detectors ───────────────────────────────────────────────────────

# Output: STATUS|CURRENT|LATEST
detect_ga() {
  local installed latest status
  installed=$(get_installed_ga_version)
  latest=$(get_latest_ga_version)

  if [[ -z "$installed" ]]; then
    echo "NOT_INSTALLED|-|${latest}"
    return
  fi

  if [[ "$installed" == "$latest" || "$latest" == "unknown" || "$installed" > "$latest" ]]; then
    status="UP_TO_DATE"
  else
    status="OUTDATED"
  fi
  echo "${status}|${installed}|${latest}"
}

# Output: STATUS|INSTALLED_COUNT|TOTAL (9 sdd-* skills expected)
# $1: optional skills directory (defaults to ./skills)
detect_sdd() {
  local skills_dir="${1:-.}/skills"
  local count=0 total=9

  if [[ -d "$skills_dir" ]]; then
    for d in "$skills_dir"/sdd-*; do [[ -d "$d" ]] && ((count++)) || true; done
  fi

  if   [[ $count -eq 0 ]];     then echo "NOT_INSTALLED|0|${total}"
  elif [[ $count -ge $total ]]; then echo "INSTALLED|${count}|${total}"
  else                               echo "PARTIAL|${count}|${total}"
  fi
}

# Output: STATUS|INSTALLED|TOTAL|MISSING_LIST
detect_vscode_extensions() {
  local extensions=("github.copilot" "github.copilot-chat")
  local total=${#extensions[@]} installed=0
  local missing=()

  if ! command_exists code; then
    echo "NOT_AVAILABLE|0|${total}|VS Code CLI not found"
    return
  fi

  local installed_list
  installed_list=$(code --list-extensions 2>/dev/null || true)

  for ext in "${extensions[@]}"; do
    if echo "$installed_list" | grep -qi "^${ext}$"; then
      ((installed++))
    else
      missing+=("$ext")
    fi
  done

  local status
  if   [[ $installed -eq 0 ]];     then status="NOT_INSTALLED"
  elif [[ $installed -eq $total ]]; then status="INSTALLED"
  else                                   status="PARTIAL"
  fi
  echo "${status}|${installed}|${total}|${missing[*]}"
}

# Output: GIT|NODE|NPM|VSCODE
detect_prerequisites() {
  local git_v node_v npm_v vscode

  command_exists git  && git_v=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  command_exists node && node_v=$(node --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  command_exists npm  && npm_v=$(npm --version 2>/dev/null)
  command_exists code && vscode="available" || vscode="not_found"

  echo "${git_v:-not_found}|${node_v:-not_found}|${npm_v:-not_found}|${vscode}"
}

# ── Check whether a GA git repo has upstream commits ─────────────────────────
# Returns 0 when updates are available.
# Prefers semver comparison via GitHub API; falls back to git commit count.
ga_updates_available() {
  local ga_path="$1"
  [[ -d "$ga_path/.git" ]] || return 1

  local installed latest
  installed=$(get_installed_ga_version)
  latest=$(get_latest_ga_version)

  if [[ -n "$installed" && "$latest" != "unknown" && "$installed" != "$latest" ]]; then
    return 0
  fi

  (cd "$ga_path" && git fetch origin -q 2>/dev/null) || return 1
  local behind
  behind=$(cd "$ga_path" && \
    git rev-list HEAD..origin/main --count 2>/dev/null || \
    git rev-list HEAD..origin/master --count 2>/dev/null)
  [[ -n "$behind" && "$behind" -gt 0 ]]
}

# ── Direct execution ──────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-all}" in
    ga)    detect_ga ;;
    sdd)   detect_sdd ;;
    vscode) detect_vscode_extensions ;;
    prereq) detect_prerequisites ;;
    all)
      echo "GA:$(detect_ga)"
      echo "SDD:$(detect_sdd)"
      echo "VSCODE:$(detect_vscode_extensions)"
      echo "PREREQ:$(detect_prerequisites)"
      ;;
    *) echo "Usage: $0 {ga|sdd|vscode|prereq|all}"; exit 1 ;;
  esac
fi
