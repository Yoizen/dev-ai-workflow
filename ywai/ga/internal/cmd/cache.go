package cmd

import (
	"github.com/yoizen/ga/internal/cache"
	"github.com/yoizen/ga/internal/ui"

	"github.com/spf13/cobra"
)

var cacheCmd = &cobra.Command{
	Use:   "cache [status|clear|clear-all]",
	Short: "Manage cache",
	Args:  cobra.MaximumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		subcmd := "status"
		if len(args) > 0 {
			subcmd = args[0]
		}
		return runCache(subcmd)
	},
}

func init() {
	rootCmd.AddCommand(cacheCmd)
}

func runCache(subcmd string) error {
	ui.PrintBanner("dev")

	switch subcmd {
	case "clear":
		if err := cache.InvalidateCache(); err != nil {
			ui.Error("Failed to clear cache: %v", err)
			return err
		}
		ui.Success("Cleared cache for current project")
	case "clear-all":
		if err := cache.ClearAllCache(); err != nil {
			ui.Error("Failed to clear all cache: %v", err)
			return err
		}
		ui.Success("Cleared all cache data")
	case "status":
		ui.Info("Cache Status:")

		cacheDir, err := cache.GetProjectCacheDir()
		if err != nil {
			ui.Info("  Project cache: Not initialized (not in a git repo?)")
		} else if _, err := cache.GetProjectCacheDir(); err != nil {
			ui.Info("  Project cache: Not initialized")
		} else {
			ui.Info("  Cache directory: %s", cacheDir)

			valid := cache.IsCacheValid("REVIEW.md", ".ga")
			if valid {
				ui.Info("  Cache validity: Valid")
			} else {
				ui.Warning("Cache validity: Invalid (rules or config changed)")
			}

			count, _, size, _ := cache.GetCacheStats()
			ui.Info("  Cached files: %d", count)
			if size != "" {
				ui.Info("  Cache size: %s", size)
			}
		}
	default:
		ui.Error("Unknown cache command: %s", subcmd)
		ui.Info("Available commands: ga cache status, ga cache clear, ga cache clear-all")
	}

	return nil
}
