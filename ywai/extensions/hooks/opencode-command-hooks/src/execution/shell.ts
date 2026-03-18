/**
 * Shell command execution module for opencode-command-hooks
 *
 * Provides functions to execute shell commands using Bun's $ template literals
 * with proper error handling, output capture, and truncation.
 *
 * Key features:
 * - Execute single or multiple commands sequentially
 * - Capture stdout, stderr, and exit codes
 * - Truncate output to configurable limit (default: 30,000 chars, matching OpenCode)
 * - Never throw errors - always return results
 * - Support debug logging via OPENCODE_HOOKS_DEBUG
 */

import type { HookExecutionResult } from "../types/hooks.js"
import { execFile } from "child_process";
import { logger, isDebugEnabled } from "../logging.js"

const DEFAULT_TRUNCATE_LIMIT = 30_000

/**
 * Truncate text to a maximum length, matching OpenCode's bash tool behavior
 */
const truncateText = (text: string | undefined, limit: number): string => {
  if (!text) return ""
  if (text.length <= limit) return text
  
  const truncated = text.slice(0, limit)
  const metadata = `\n\n[Output truncated: exceeded ${limit} character limit]`
  
  return truncated + metadata
}

/**
 * Execute a single shell command
 *
 * @param command - Shell command to execute
 * @param options - Execution options
 * @returns HookExecutionResult with command output and exit code
 *
 * @example
 * ```typescript
 * const result = await executeCommand("pnpm test")
 * console.log(result.exitCode, result.stdout)
 * 
 * // With custom truncation limit
 * const result = await executeCommand("pnpm test", { truncateOutput: 5000 })
 * ```
 */
export async function executeCommand(
   command: string,
   options?: { truncateOutput?: number }
): Promise<HookExecutionResult> {
   const truncateLimit = options?.truncateOutput ?? DEFAULT_TRUNCATE_LIMIT
  const hookId = "command" // Will be set by caller

    if (isDebugEnabled()) {
      logger.debug(`Executing command: ${command}`)
    }

  try {
    // Execute command using Bun's $ template literal with nothrow to prevent throwing on non-zero exit
    // We need to use dynamic template literal evaluation
    const result = await executeShellCommand(command)

    const stdout = truncateText(result.stdout, truncateLimit)
    const stderr = truncateText(result.stderr, truncateLimit)
    const exitCode = result.exitCode ?? 0
    const success = exitCode === 0

      if (isDebugEnabled()) {
        logger.debug(`Command completed: exit ${exitCode}, stdout length: ${stdout.length}, stderr length: ${stderr.length}`)
      }

    return {
      hookId,
      success,
      exitCode,
      stdout,
      stderr,
    }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err)
      logger.error(`Failed to execute command: ${errorMessage}`)

    return {
      hookId,
      success: false,
      error: errorMessage,
    }
  }
}

/**
 * Execute multiple shell commands sequentially
 *
 * Commands run one after another, even if earlier commands fail.
 * Each command's result is captured and returned separately.
 *
 * @param commands - Single command string or array of command strings
 * @param hookId - Hook ID for tracking (included in results)
 * @param options - Execution options
 * @returns Array of HookExecutionResult, one per command
 *
 * @example
 * ```typescript
 * const results = await executeCommands(
 *   ["pnpm lint", "pnpm test"],
 *   "my-hook",
 *   { truncateOutput: 2000 }
 * )
 * results.forEach(r => console.log(r.exitCode))
 * ```
 */
export async function executeCommands(
  commands: string | string[],
  hookId: string,
  options?: { truncateOutput?: number }
): Promise<HookExecutionResult[]> {
  const truncateLimit = options?.truncateOutput ?? DEFAULT_TRUNCATE_LIMIT
  const commandArray = Array.isArray(commands) ? commands : [commands]

    if (isDebugEnabled()) {
      logger.debug(`Executing ${commandArray.length} command(s) for hook "${hookId}"`)
    }

  const results: HookExecutionResult[] = []

  for (const command of commandArray) {
    try {
       if (isDebugEnabled()) {
          logger.debug(`[${hookId}] Executing: ${command}`)
        }

      const result = await executeShellCommand(command)

      const stdout = truncateText(result.stdout, truncateLimit)
      const stderr = truncateText(result.stderr, truncateLimit)
      const exitCode = result.exitCode ?? 0
      const success = exitCode === 0

        if (isDebugEnabled()) {
          logger.debug(`[${hookId}] Command completed: exit ${exitCode}, stdout length: ${stdout.length}, stderr length: ${stderr.length}`)
        }

      results.push({
        hookId,
        success,
        exitCode,
        stdout,
        stderr,
      })
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : String(err)
        logger.error(`[${hookId}] Failed to execute command: ${errorMessage}`)

      results.push({
        hookId,
        success: false,
        error: errorMessage,
      })
    }
  }

  return results
}

/**
 * Internal helper to execute a shell command using Node.js child_process
 *
 * This function handles the actual shell execution with proper error handling.
 * Uses execFile with shell: true to execute commands, capturing stdout and stderr
 * without printing to console.
 *
 * @param command - Shell command to execute
 * @returns Object with stdout, stderr, and exitCode
 */
const executeShellCommand = async (
  command: string
): Promise<{ stdout: string; stderr: string; exitCode: number }> => {
  return new Promise((resolve) => {
    execFile("sh", ["-c", command], { encoding: "utf-8" }, (error, stdout, stderr) => {
      // execFile callback is called when the process exits
      // error is null if the process exits with code 0
      // error.code is the exit code if non-zero
      const exitCode = error?.code ?? 0;
      
      resolve({
        stdout: stdout || "",
        stderr: stderr || "",
        exitCode: typeof exitCode === "number" ? exitCode : 1,
      });
    });
  });
};
