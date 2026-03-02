# shellcheck shell=bash

Describe 'ga commands'
  # Path to the ga script
  ga() {
    "$PROJECT_ROOT/bin/ga" "$@"
  }

  Describe 'ga version'
    It 'returns version number'
      When call ga version
      The status should be success
      The output should include "ga v"
    End

    It 'accepts --version flag'
      When call ga --version
      The status should be success
      The output should include "ga v"
    End

    It 'accepts -v flag'
      When call ga -v
      The status should be success
      The output should include "ga v"
    End
  End

  Describe 'ga help'
    It 'shows help message'
      When call ga help
      The status should be success
      The output should include "USAGE"
      The output should include "COMMANDS"
    End

    It 'accepts --help flag'
      When call ga --help
      The status should be success
      The output should include "USAGE"
    End

    It 'shows help when no command given'
      When call ga
      The status should be success
      The output should include "USAGE"
    End

    It 'lists all commands'
      When call ga help
      The output should include "run"
      The output should include "install"
      The output should include "uninstall"
      The output should include "config"
      The output should include "init"
      The output should include "cache"
    End
  End

  Describe 'ga init'
    setup() {
      TEMP_DIR=$(mktemp -d)
      cd "$TEMP_DIR"
    }

    cleanup() {
      cd /
      rm -rf "$TEMP_DIR"
    }

    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'creates .ga config file'
      When call ga init
      The status should be success
      The output should be present
      The path ".ga" should be file
    End

    It 'config file contains PROVIDER'
      ga init > /dev/null
      The contents of file ".ga" should include "PROVIDER"
    End

    It 'config file contains FILE_PATTERNS'
      ga init > /dev/null
      The contents of file ".ga" should include "FILE_PATTERNS"
    End

    It 'config file contains EXCLUDE_PATTERNS'
      ga init > /dev/null
      The contents of file ".ga" should include "EXCLUDE_PATTERNS"
    End

    It 'config file contains RULES_FILE'
      ga init > /dev/null
      The contents of file ".ga" should include "RULES_FILE"
    End

    It 'config file contains STRICT_MODE'
      ga init > /dev/null
      The contents of file ".ga" should include "STRICT_MODE"
    End
  End

  Describe 'ga config'
    setup() {
      TEMP_DIR=$(mktemp -d)
      cd "$TEMP_DIR"
    }

    cleanup() {
      cd /
      rm -rf "$TEMP_DIR"
    }

    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'shows configuration'
      When call ga config
      The status should be success
      The output should include "Configuration"
    End

    It 'shows provider not configured when no config'
      When call ga config
      The output should include "Not configured"
    End

    It 'shows provider when configured'
      echo 'PROVIDER="claude"' > .ga
      When call ga config
      The output should include "claude"
    End

    It 'shows rules file status'
      When call ga config
      The output should include "Rules File"
    End
  End

  Describe 'ga install'
    setup() {
      TEMP_DIR=$(mktemp -d)
      cd "$TEMP_DIR"
      git init --quiet
    }

    cleanup() {
      cd /
      rm -rf "$TEMP_DIR"
    }

    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'creates pre-commit hook'
      When call ga install
      The status should be success
      The output should be present
      The path ".git/hooks/pre-commit" should be file
    End

    It 'hook contains ga run command'
      ga install > /dev/null
      The contents of file ".git/hooks/pre-commit" should include "ga run"
    End

    It 'hook is executable'
      ga install > /dev/null
      The path ".git/hooks/pre-commit" should be executable
    End

    It 'fails if not in git repo'
      rm -rf .git
      When call ga install
      The status should be failure
      The output should include "Not a git repository"
    End
  End

  Describe 'ga uninstall'
    setup() {
      TEMP_DIR=$(mktemp -d)
      cd "$TEMP_DIR"
      git init --quiet
      ga install > /dev/null
    }

    cleanup() {
      cd /
      rm -rf "$TEMP_DIR"
    }

    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'removes pre-commit hook'
      When call ga uninstall
      The status should be success
      The output should be present
      The path ".git/hooks/pre-commit" should not be exist
    End

    It 'succeeds if hook does not exist'
      rm .git/hooks/pre-commit
      When call ga uninstall
      The status should be success
      The output should be present
    End
  End

  Describe 'ga cache'
    setup() {
      TEMP_DIR=$(mktemp -d)
      cd "$TEMP_DIR"
      git init --quiet
      echo "rules" > REVIEW.md
      echo 'PROVIDER="claude"' > .ga
    }

    cleanup() {
      cd /
      rm -rf "$TEMP_DIR"
    }

    BeforeEach 'setup'
    AfterEach 'cleanup'

    Describe 'ga cache status'
      It 'shows cache status'
        When call ga cache status
        The status should be success
        The output should include "Cache Status"
      End
    End

    Describe 'ga cache clear'
      It 'clears project cache'
        When call ga cache clear
        The status should be success
        The output should include "Cleared cache"
      End
    End

    Describe 'ga cache clear-all'
      It 'clears all cache'
        When call ga cache clear-all
        The status should be success
        The output should include "Cleared all cache"
      End
    End

    Describe 'invalid subcommand'
      It 'fails for unknown cache subcommand'
        When call ga cache invalid
        The status should be failure
        The output should include "Unknown cache command"
      End
    End
  End

  Describe 'unknown command'
    It 'fails with error message'
      When call ga unknown-command
      The status should be failure
      The output should include "Unknown command"
    End
  End
End
