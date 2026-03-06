package sync

type SyncReport struct {
	ProjectType     string
	DetectedType    string
	SkillsMissing   []SkillInfo
	SkillsUpdated   []SkillInfo
	AgentsMDChanges AgentsMDChanges
	ReviewMDChanges ReviewMDChanges
	Instructions    []Instruction
	SourcePaths     map[string]string
}

type SkillsReport struct {
	Missing  []SkillInfo
	Updated  []SkillInfo
	Existing []string
}

type SkillInfo struct {
	Name         string
	Path         string
	Status       string
	Description  string
	Dependencies []string
}

type AgentsMDChanges struct {
	NewSections   []SectionInfo
	UpdatedTables []TableInfo
	ManagedBlocks []ManagedBlock
}

type ReviewMDChanges struct {
	NewRules     []RuleInfo
	UpdatedRules []RuleInfo
}

type Instruction struct {
	Step        int
	Title       string
	Description string
	Commands    []string
}

type SectionInfo struct {
	Title   string
	After   string
	Content string
}

type TableInfo struct {
	Name    string
	AddRows []string
}

type ManagedBlock struct {
	BlockID string
	Content string
}

type RuleInfo struct {
	Title       string
	After       string
	Description string
}

type InstallReport struct {
	SkillName    string
	Files        []SkillFile
	Dependencies []SkillInfo
	Summary      string
	Instructions []Instruction
	SourcePaths  map[string]string
}

type SkillFile struct {
	Source      string
	Destination string
}

type TypesConfig struct {
	Types      map[string]ProjectType `json:"types"`
	BaseConfig BaseConfig             `json:"base_config"`
	Default    string                 `json:"default"`
}

type ProjectType struct {
	Description  string              `json:"description"`
	AgentsMD     string              `json:"agents_md"`
	ReviewMD     string              `json:"review_md"`
	LefthookYML  string              `json:"lefthook_yml"`
	GlobalAgents []string            `json:"global_agents"`
	Skills       []string            `json:"skills"`
	Extensions   map[string][]string `json:"extensions"`
}

type BaseConfig struct {
	Description           string              `json:"description"`
	AppendAgentsTemplates []string            `json:"append_agents_templates"`
	Extensions            map[string][]string `json:"extensions"`
	CopySharedSkills      bool                `json:"copy_shared_skills"`
	CopyCommands          bool                `json:"copy_commands"`
	InitGA                bool                `json:"init_ga"`
}

type SyncFlags struct {
	ProjectType string
	Force       bool
	DryRun      bool
}
