import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import { mkdir, rm, writeFile } from "fs/promises";
import { join } from "path";
import { tmpdir } from "os";
import {
  applyDisabledHookIds,
  loadProjectConfig,
} from "../src/config/project";

describe("Project hooks configuration", () => {
  const testProjectDir = join(
    tmpdir(),
    `opencode-project-hooks-${Date.now().toString(36)}`,
  );

  beforeEach(async () => {
    await mkdir(testProjectDir, { recursive: true });
  });

  afterEach(async () => {
    try {
      await rm(testProjectDir, { recursive: true, force: true });
    } catch {
      // Ignore cleanup errors in tests
    }
  });

  it("returns empty config when .hooks-config.yml is missing", async () => {
    const originalCwd = process.cwd();
    try {
      process.chdir(testProjectDir);
      const result = await loadProjectConfig();
      expect(result.config).toEqual({ tool: [], session: [] });
      expect(result.disabledIds).toEqual([]);
      expect(result.error).toBeNull();
    } finally {
      process.chdir(originalCwd);
    }
  });

  it("loads simplified tool hooks from .hooks-config.yml", async () => {
    await writeFile(
      join(testProjectDir, ".hooks-config.yml"),
      `project_hooks:
  enabled:
    - name: "typescript-lint"
      command: "npm run lint"
      trigger: "after"
      inject: "Lint Results:\\n{stdout}"
`,
    );

    const originalCwd = process.cwd();
    try {
      process.chdir(testProjectDir);
      const result = await loadProjectConfig();

      expect(result.error).toBeNull();
      expect(result.config.tool).toHaveLength(1);
      expect(result.config.tool?.[0]).toEqual({
        id: "typescript-lint",
        when: {
          phase: "after",
          tool: ["edit", "write"],
        },
        run: "npm run lint",
        inject: "Lint Results:\n{stdout}",
      });
      expect(result.config.session).toEqual([]);
    } finally {
      process.chdir(originalCwd);
    }
  });

  it("loads session hooks and settings from .hooks-config.yml", async () => {
    await writeFile(
      join(testProjectDir, ".hooks-config.yml"),
      `project_hooks:
  enabled:
    - name: "session-summary"
      trigger: "session.idle"
      command: "git status --short"
      agent: "engineer"
      inject: "Status:\\n{stdout}"
  settings:
    truncation_limit: 1234
  disabled:
    - "legacy-hook"
`,
    );

    const originalCwd = process.cwd();
    try {
      process.chdir(testProjectDir);
      const result = await loadProjectConfig();

      expect(result.error).toBeNull();
      expect(result.config.truncationLimit).toBe(1234);
      expect(result.disabledIds).toEqual(["legacy-hook"]);
      expect(result.config.session).toHaveLength(1);
      expect(result.config.session?.[0]).toEqual({
        id: "session-summary",
        when: {
          event: "session.idle",
          agent: "engineer",
        },
        run: "git status --short",
        inject: "Status:\n{stdout}",
      });
    } finally {
      process.chdir(originalCwd);
    }
  });

  it("supports yaml variant and full when syntax", async () => {
    await writeFile(
      join(testProjectDir, ".hooks-config.yaml"),
      `project_hooks:
  enabled:
    - id: "validate-engineer"
      run:
        - "npm run lint"
        - "npm test"
      when:
        phase: "after"
        tool: "task"
        callingAgent: "engineer"
`,
    );

    const originalCwd = process.cwd();
    try {
      process.chdir(testProjectDir);
      const result = await loadProjectConfig();

      expect(result.error).toBeNull();
      expect(result.config.tool).toHaveLength(1);
      expect(result.config.tool?.[0]).toEqual({
        id: "validate-engineer",
        when: {
          phase: "after",
          tool: "task",
          callingAgent: "engineer",
        },
        run: ["npm run lint", "npm test"],
      });
    } finally {
      process.chdir(originalCwd);
    }
  });

  it("reports invalid enabled entries without crashing", async () => {
    await writeFile(
      join(testProjectDir, ".hooks-config.yml"),
      `project_hooks:
  enabled:
    - "not-an-object"
    - name: "missing-command"
      trigger: "after"
`,
    );

    const originalCwd = process.cwd();
    try {
      process.chdir(testProjectDir);
      const result = await loadProjectConfig();

      expect(result.config).toEqual({ tool: [], session: [] });
      expect(result.error).toContain("Invalid hook entries");
    } finally {
      process.chdir(originalCwd);
    }
  });

  it("removes disabled hook ids from tool and session hooks", () => {
    const config = {
      truncationLimit: 30000,
      tool: [
        {
          id: "keep-tool",
          when: { phase: "after" as const },
          run: "echo keep",
        },
        {
          id: "drop-tool",
          when: { phase: "after" as const },
          run: "echo drop",
        },
      ],
      session: [
        {
          id: "drop-session",
          when: { event: "session.idle" as const },
          run: "echo drop",
        },
      ],
    };

    const filtered = applyDisabledHookIds(config, [
      "drop-tool",
      "drop-session",
    ]);

    expect(filtered.tool).toEqual([
      {
        id: "keep-tool",
        when: { phase: "after" },
        run: "echo keep",
      },
    ]);
    expect(filtered.session).toEqual([]);
    expect(filtered.truncationLimit).toBe(30000);
  });
});
