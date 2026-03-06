/**
 * Project hooks configuration loader for `.hooks-config.yml`
 *
 * Provides a friendlier project-local configuration format that compiles down
 * to the existing CommandHooksConfig runtime model used by the plugin.
 *
 * Supported first-phase features:
 * - `project_hooks.enabled`: additional tool/session hooks
 * - `project_hooks.disabled`: hook IDs to remove from the merged config
 * - `project_hooks.settings.truncation_limit`: override output truncation
 */

import type { CommandHooksConfig, SessionHook, ToolHook } from "../types/hooks.js";
import { load as parseYaml } from "js-yaml";
import { access, constants, readFile } from "fs/promises";
import { dirname, join } from "path";
import { logger } from "../logging.js";

type ProjectConfigResult = {
  config: CommandHooksConfig;
  disabledIds: string[];
  error: string | null;
};

type ToastConfig = {
  title?: string;
  message: string;
  variant?: "info" | "success" | "warning" | "error";
  duration?: number;
};

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;

const isStringArray = (value: unknown): value is string[] =>
  Array.isArray(value) && value.every((item) => typeof item === "string");

const readString = (...values: unknown[]): string | undefined =>
  values.find((value) => typeof value === "string") as string | undefined;

const readStringOrArray = (
  ...values: unknown[]
): string | string[] | undefined => {
  for (const value of values) {
    if (typeof value === "string") return value;
    if (isStringArray(value)) return value;
  }
  return undefined;
};

const readToast = (value: unknown): ToastConfig | undefined => {
  if (!isRecord(value) || typeof value.message !== "string") {
    return undefined;
  }

  const toast: ToastConfig = {
    message: value.message,
  };

  if (typeof value.title === "string") {
    toast.title = value.title;
  }
  if (
    value.variant === "info" ||
    value.variant === "success" ||
    value.variant === "warning" ||
    value.variant === "error"
  ) {
    toast.variant = value.variant;
  }
  if (typeof value.duration === "number") {
    toast.duration = value.duration;
  }

  return toast;
};

const parseToolHook = (entry: Record<string, unknown>): ToolHook | null => {
  const when = isRecord(entry.when) ? entry.when : {};
  const id = readString(entry.id, entry.name);
  const phase = readString(when.phase, entry.trigger);
  const run = readStringOrArray(entry.run, entry.command, entry.commands);

  if (!id || !run || (phase !== "before" && phase !== "after")) {
    return null;
  }

  const hook: ToolHook = {
    id,
    when: {
      phase,
    },
    run,
  };

  const tool = readStringOrArray(when.tool, entry.tool);
  const callingAgent = readStringOrArray(
    when.callingAgent,
    when.calling_agent,
    entry.callingAgent,
    entry.calling_agent,
  );
  const slashCommand = readStringOrArray(
    when.slashCommand,
    when.slash_command,
    entry.slashCommand,
    entry.slash_command,
  );
  const toolArgs = isRecord(when.toolArgs)
    ? when.toolArgs
    : isRecord(when.tool_args)
      ? when.tool_args
      : isRecord(entry.toolArgs)
        ? entry.toolArgs
        : isRecord(entry.tool_args)
          ? entry.tool_args
          : undefined;

  hook.when.tool = tool ?? ["edit", "write"];
  if (callingAgent) {
    hook.when.callingAgent = callingAgent;
  }
  if (slashCommand) {
    hook.when.slashCommand = slashCommand;
  }
  if (toolArgs) {
    hook.when.toolArgs = toolArgs as Record<string, string | string[]>;
  }
  if (typeof entry.inject === "string") {
    hook.inject = entry.inject;
  }

  const toast = readToast(entry.toast);
  if (toast) {
    hook.toast = toast;
  }

  return hook;
};

const parseSessionHook = (entry: Record<string, unknown>): SessionHook | null => {
  const when = isRecord(entry.when) ? entry.when : {};
  const id = readString(entry.id, entry.name);
  const event = readString(when.event, entry.trigger);
  const run = readStringOrArray(entry.run, entry.command, entry.commands);

  if (
    !id ||
    !run ||
    (event !== "session.created" &&
      event !== "session.start" &&
      event !== "session.idle" &&
      event !== "session.end")
  ) {
    return null;
  }

  const hook: SessionHook = {
    id,
    when: {
      event,
    },
    run,
  };

  const agent = readStringOrArray(when.agent, entry.agent);
  if (agent) {
    hook.when.agent = agent;
  }
  if (typeof entry.inject === "string") {
    hook.inject = entry.inject;
  }

  const toast = readToast(entry.toast);
  if (toast) {
    hook.toast = toast;
  }

  return hook;
};

const parseEnabledHookEntry = (
  entry: unknown,
): ToolHook | SessionHook | null => {
  if (!isRecord(entry)) {
    return null;
  }

  const explicitType = readString(entry.type);
  const trigger = readString(entry.trigger);
  const when = isRecord(entry.when) ? entry.when : {};
  const whenEvent = readString(when.event);

  if (
    explicitType === "session" ||
    (typeof trigger === "string" && trigger.startsWith("session.")) ||
    typeof whenEvent === "string"
  ) {
    return parseSessionHook(entry);
  }

  return parseToolHook(entry);
};

const isSessionHook = (hook: ToolHook | SessionHook): hook is SessionHook =>
  "event" in hook.when;

const parseYamlContent = (
  content: string,
): { config: CommandHooksConfig; disabledIds: string[]; error: string | null } => {
  let parsed: unknown;

  try {
    parsed = parseYaml(content);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      config: { tool: [], session: [] },
      disabledIds: [],
      error: `Failed to parse .hooks-config.yml: ${message}`,
    };
  }

  if (!isRecord(parsed)) {
    return { config: { tool: [], session: [] }, disabledIds: [], error: null };
  }

  const projectHooks = isRecord(parsed.project_hooks)
    ? parsed.project_hooks
    : parsed;

  const enabled = Array.isArray(projectHooks.enabled)
    ? projectHooks.enabled
    : [];
  const disabledIds = isStringArray(projectHooks.disabled)
    ? projectHooks.disabled
    : [];
  const settings = isRecord(projectHooks.settings) ? projectHooks.settings : {};

  const tool: ToolHook[] = [];
  const session: SessionHook[] = [];
  const invalidEntries: number[] = [];

  enabled.forEach((entry, index) => {
    const hook = parseEnabledHookEntry(entry);
    if (!hook) {
      invalidEntries.push(index);
      return;
    }

    if (isSessionHook(hook)) {
      session.push(hook);
    } else {
      tool.push(hook);
    }
  });

  const config: CommandHooksConfig = {
    tool,
    session,
  };

  if (
    typeof settings.truncation_limit === "number" &&
    Number.isInteger(settings.truncation_limit) &&
    settings.truncation_limit > 0
  ) {
    config.truncationLimit = settings.truncation_limit;
  }

  const error =
    invalidEntries.length > 0
      ? `Invalid hook entries in .hooks-config.yml at indexes: ${invalidEntries.join(", ")}`
      : null;

  return { config, disabledIds, error };
};

const findProjectConfigFile = async (startDir: string): Promise<string | null> => {
  let currentDir = startDir;
  const maxDepth = 20;
  let depth = 0;

  while (depth < maxDepth) {
    const candidates = [
      join(currentDir, ".hooks-config.yml"),
      join(currentDir, ".hooks-config.yaml"),
    ];

    for (const candidate of candidates) {
      try {
        await access(candidate, constants.F_OK);
        logger.debug(`Found project hooks config file: ${candidate}`);
        return candidate;
      } catch {
        // Continue searching
      }
    }

    const parentDir = dirname(currentDir);
    if (parentDir === currentDir) {
      break;
    }

    currentDir = parentDir;
    depth++;
  }

  return null;
};

export const loadProjectConfig = async (): Promise<ProjectConfigResult> => {
  try {
    const configPath = await findProjectConfigFile(process.cwd());

    if (!configPath) {
      return { config: { tool: [], session: [] }, disabledIds: [], error: null };
    }

    let content: string;
    try {
      content = await readFile(configPath, "utf-8");
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        config: { tool: [], session: [] },
        disabledIds: [],
        error: `Failed to read ${configPath}: ${message}`,
      };
    }

    return parseYamlContent(content);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      config: { tool: [], session: [] },
      disabledIds: [],
      error: `Unexpected error loading .hooks-config.yml: ${message}`,
    };
  }
};

export const applyDisabledHookIds = (
  config: CommandHooksConfig,
  disabledIds: string[],
): CommandHooksConfig => {
  if (disabledIds.length === 0) {
    return config;
  }

  const disabled = new Set(disabledIds);

  return {
    ...config,
    tool: (config.tool ?? []).filter((hook) => !disabled.has(hook.id)),
    session: (config.session ?? []).filter((hook) => !disabled.has(hook.id)),
  };
};
