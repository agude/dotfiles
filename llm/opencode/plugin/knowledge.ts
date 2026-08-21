// OpenCode plugin — Knowledge base session capture.
//
// Mirrors the four-hook pattern from Claude Code and Codex:
//   session.created              → session-init + session-context
//   chat.message                 → session-append --role user
//   message.updated (assistant)  → session-append --role assistant
//   dispose                      → session-flush
//
// Gating: capture is on unless KNOWLEDGE_OBSERVE=0, matching the Claude Code
// hooks. Nothing in the OpenCode launch path sets the variable, so an opt-in
// default would silently no-op whenever OpenCode starts outside an
// rc-sourcing shell (GUI launcher, script, bare tmux).
//
// Failures are reported on stderr — once per distinct cause — because every
// capture path is best-effort and would otherwise fail invisibly.

import type { Plugin } from "@opencode-ai/plugin"
import { execFile as execFileCb } from "node:child_process"
import { existsSync } from "node:fs"
import { promisify } from "node:util"

const execFile = promisify(execFileCb)

const KB = process.env.KNOWLEDGE_BASE ?? ""
const OBSERVE = process.env.KNOWLEDGE_OBSERVE !== "0"

const warned = new Set<string>()

// OpenCode does not route plugin output into its own log file, so warnings
// land on the server's stderr. Deduplicate by cause: a broken KB script must
// not print on every message.
function warn(key: string, message: string): void {
  if (warned.has(key)) return
  warned.add(key)
  console.error(`knowledge plugin: ${message}`)
}

function kbScript(name: string): string {
  return `${KB}/scripts/${name}`
}

async function run(script: string, args: string[], timeoutMs = 10_000): Promise<string> {
  try {
    const { stdout } = await execFile(script, args, {
      timeout: timeoutMs,
      encoding: "utf-8",
    })
    return stdout.trim()
  } catch (error) {
    const failure = error as { stderr?: string; message?: string }
    const detail = (failure.stderr || failure.message || "unknown error").trim()
    warn(script, `${script} failed: ${detail}`)
    return ""
  }
}

function extractText(parts: Array<{ type: string; text?: string }>): string {
  return parts
    .filter((p): p is { type: "text"; text: string } => p.type === "text")
    .map((p) => p.text)
    .join("\n")
}

export default (async ({ client }) => {
  // No knowledge base configured: this machine does not want capture at all.
  if (!KB) return {}

  if (!existsSync(kbScript("session-init"))) {
    warn("missing", `KNOWLEDGE_BASE=${KB} has no scripts/session-init; capture disabled`)
    return {}
  }

  const sessionFiles = new Map<string, string>()
  const appendedMessages = new Set<string>()
  // Child sessions are OpenCode's subagents. They do not observe, matching
  // the Claude Code rule: one transcript per human conversation, not one per
  // delegated task.
  const childSessions = new Set<string>()
  // Cached for the life of the process on purpose: Claude Code injects KB
  // context once at SessionStart, and re-reading per request would let the
  // instructions change underneath a running conversation.
  let contextCache: string | undefined

  async function getContext(): Promise<string> {
    if (contextCache === undefined) {
      contextCache = await run(kbScript("session-context"), [])
    }
    return contextCache
  }

  async function initSession(sessionID: string): Promise<void> {
    if (!OBSERVE) return
    if (childSessions.has(sessionID)) return
    if (sessionFiles.has(sessionID)) return
    const file = await run(kbScript("session-init"), ["--session-id", sessionID])
    if (file) sessionFiles.set(sessionID, file)
  }

  // The knowledge base sweeps buffers left idle for an hour, flushing and
  // deleting them. session-append no-ops silently on a missing file, so a
  // long-lived OpenCode session whose buffer was swept would go deaf for the
  // rest of the process. Re-initialize instead.
  async function bufferFor(sessionID: string): Promise<string | undefined> {
    const known = sessionFiles.get(sessionID)
    if (known && existsSync(known)) return known
    if (known) sessionFiles.delete(sessionID)
    await initSession(sessionID)
    return sessionFiles.get(sessionID)
  }

  async function appendMessage(
    sessionID: string,
    role: "user" | "assistant",
    message: string,
  ): Promise<void> {
    if (!OBSERVE || !message) return
    const file = await bufferFor(sessionID)
    if (!file) return
    await run(kbScript("session-append"), [
      "--file", file,
      "--role", role,
      "--message", message,
    ])
  }

  async function flushSession(sessionID: string): Promise<void> {
    if (!OBSERVE) return
    const file = sessionFiles.get(sessionID)
    if (!file) return
    sessionFiles.delete(sessionID)
    if (!existsSync(file)) return
    await run(kbScript("session-flush"), [file], 15_000)
  }

  async function flushAll(): Promise<void> {
    const flushes = [...sessionFiles.keys()].map((sid) => flushSession(sid))
    await Promise.allSettled(flushes)
  }

  return {
    event: async ({ event }) => {
      // Event payloads are OpenCode's shape, not ours; an unexpected one must
      // not throw inside their dispatcher.
      try {
        if (event.type === "session.created") {
          const info = event.properties.info as { id: string; parentID?: string }
          if (info.parentID) {
            childSessions.add(info.id)
            return
          }
          await initSession(info.id)
          return
        }

        if (event.type === "message.updated") {
          const msg = event.properties.info
          if (msg.role !== "assistant" || !msg.time.completed) return

          const key = `${msg.sessionID}:${msg.id}`
          if (appendedMessages.has(key)) return
          appendedMessages.add(key)

          if (!sessionFiles.has(msg.sessionID)) return

          const result = await client.session.message({
            path: { id: msg.sessionID, messageID: msg.id },
          })
          if (!result.data) return
          // Text only, like the Claude and Codex shims: the transcript records
          // the conversation, not the tool traffic.
          const text = extractText(result.data.parts as Array<{ type: string; text?: string }>)
          if (text) {
            await appendMessage(msg.sessionID, "assistant", text)
          }
        }
      } catch (error) {
        warn("event", `${event.type} handler failed: ${String(error)}`)
      }
    },

    "chat.message": async ({ sessionID }, { parts }) => {
      try {
        if (!sessionID || childSessions.has(sessionID)) return

        const text = extractText(parts as Array<{ type: string; text?: string }>)
        if (text) {
          await appendMessage(sessionID, "user", text)
        }
      } catch (error) {
        warn("chat.message", `chat.message handler failed: ${String(error)}`)
      }
    },

    // Injection ignores OBSERVE by design: KNOWLEDGE_OBSERVE governs writing
    // transcripts, not reading the knowledge base. The Claude SessionStart
    // hook prints context on the opt-out path too.
    "experimental.chat.system.transform": async (_input, { system }) => {
      try {
        const ctx = await getContext()
        if (ctx) {
          system.push(ctx)
        }
      } catch (error) {
        warn("system.transform", `system transform failed: ${String(error)}`)
      }
    },

    dispose: async () => {
      await flushAll()
    },
  }
}) satisfies Plugin
