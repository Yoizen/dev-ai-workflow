#!/usr/bin/env bash
# ============================================================================
# GA Bulk Update — updates GA and project configs across multiple repos
# ============================================================================
# Usage: ./update-all.sh [OPTIONS] [repo1 repo2 ...]
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"
# shellcheck source=lib/detector.sh
source "$SCRIPT_DIR/lib/detector.sh"
# shellcheck source=lib/installer.sh
source "$SCRIPT_DIR/lib/installer.sh"

# ── Argument parsing ──────────────────────────────────────────────────────────

DRY_RUN=false
FORCE=false
UPDATE_TOOLS_ONLY=false
UPDATE_CONFIGS_ONLY=false
REPOSITORIES=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)            DRY_RUN=true; shift ;;
    --force)              FORCE=true; shift ;;
    --update-tools-only)  UPDATE_TOOLS_ONLY=true; shift ;;
    --update-configs-only) UPDATE_CONFIGS_ONLY=true; shift ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS] [repo1 repo2 ...]"
      echo ""
      echo "Options:"
      echo "  --dry-run               Show what would be done without changes"
      echo "  --force                 Force update configs even if they exist"
      echo "  --update-tools-only     Only update tools (skip repo configs)"
      echo "  --update-configs-only   Only update repo configs (skip tools)"
      echo "  -h, --help              Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0 /home/user/repo1 /home/user/repo2"
      echo "  $0 --dry-run /home/user/repo1"
      echo "  $0 --force /home/user/repo1"
      exit 0
      ;;
    *) REPOSITORIES+=("$1"); shift ;;
  esac
done

# ── Banner ────────────────────────────────────────────────────────────────────

print_banner "GA Bulk Update"
[[ "$DRY_RUN" == true ]] && { print_warning "DRY RUN MODE — no changes will be made"; echo ""; }

# ── Update GA globally ────────────────────────────────────────────────────────

if [[ "$UPDATE_CONFIGS_ONLY" != true ]]; then
  print_step "Checking for GA updates..."

  if ga_updates_available "$GA_DIR"; then
    if [[ "$FORCE" == true ]]; then
      do_update=true
    else
      do_update=false
      ask_yes_no "  GA update available. Update now?" "y" && do_update=true
    fi

    if [[ "$do_update" == true ]]; then
      [[ "$DRY_RUN" == true ]] \
        && print_info "[DRY RUN] Would update GA" \
        || install_ga "update"
    fi
  else
    print_success "GA is already up to date"
  fi
  echo ""
fi

# ── Update repositories ───────────────────────────────────────────────────────

if [[ "$UPDATE_TOOLS_ONLY" != true ]]; then
  if [[ ${#REPOSITORIES[@]} -eq 0 ]]; then
    print_warning "No repositories specified"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "${CYAN}  $0 /home/user/repo1 /home/user/repo2${NC}"
    echo -e "${CYAN}  $0 --dry-run /home/user/repo1${NC}"
    echo -e "${CYAN}  $0 --force /home/user/repo1${NC}"
    echo ""
    exit 0
  fi

  print_step "Updating repositories..."

  TOTAL=0; SUCCESS=0; FAILED=0; SKIPPED=0
  SETUP_SCRIPT="$SCRIPT_DIR/setup.sh"

  for repo in "${REPOSITORIES[@]}"; do
    ((TOTAL++))
    echo ""
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_info "Processing: $repo"

    if [[ ! -d "$repo" ]]; then
      print_error "Directory not found: $repo"; ((FAILED++)); continue
    fi
    if [[ ! -d "$repo/.git" ]]; then
      print_warning "Not a git repository: $repo"; ((SKIPPED++)); continue
    fi
    if [[ ! -f "$repo/.ga" ]]; then
      print_warning "GA not configured (no .ga file)"; ((SKIPPED++)); continue
    fi

    if [[ "$DRY_RUN" == true ]]; then
      print_info "[DRY RUN] Would update repository"; ((SUCCESS++)); continue
    fi

    local_flags=("--skip-sdd" "--skip-ga" "--skip-vscode")
    [[ "$FORCE" == true ]] && local_flags+=("--force")

    if bash "$SETUP_SCRIPT" "${local_flags[@]}" "$repo" 2>/dev/null; then
      print_success "Updated successfully"; ((SUCCESS++))
    else
      print_error "Failed to update"; ((FAILED++))
    fi
  done

  # Summary
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}  Summary${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${WHITE}  Total:    $TOTAL${NC}"
  echo -e "${GREEN}  Updated:  $SUCCESS${NC}"
  echo -e "${RED}  Failed:   $FAILED${NC}"
  echo -e "${YELLOW}  Skipped:  $SKIPPED${NC}"
  echo ""

  [[ $FAILED -gt 0 ]] && { print_warning "Some repositories failed — review output above"; exit 1; }
  [[ $TOTAL -gt 0 ]]  && print_success "All repositories updated!"
  echo ""
fi
