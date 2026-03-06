package version

var (
	Version   = "dev"
	Commit    = ""
	Date      = ""
	BuildInfo = Version
)

func init() {
	if Commit != "" {
		BuildInfo = Version + " (" + Commit + ")"
	}
}
