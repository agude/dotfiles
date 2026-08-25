// Pi extension — Knowledge base session capture.
//
// Ports the OpenCode plugin pattern (llm/opencode/plugin/knowledge.ts) onto
// pi's event API:
//   session_start      → session-init
//   message_end (user) → session-append --role user
//   message_end (assistant) → session-append --role assistant
//   before_agent_start → inject cached KB context into the system prompt
//   session_shutdown   → session-flush
//
// Gating: capture is on unless KNOWLEDGE_OBSERVE=0, and requires
// KNOWLEDGE_BASE to point at the knowledge base. Context injection ignores
// OBSERVE by design: the variable governs writing transcripts, not reading
// the knowledge base.
//
// Failures are reported on stderr — once per distinct cause — because every
// capture path is best-effort and would otherwise fail invisibly.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"
import { execFile as execFileCb } from "node:child_process"
import { existsSync } from "node:fs"
import { randomUUID } from "node:crypto"
import { basename, extname } from "node:path"
import { promisify } from "node:util"

const execFile = promisify(execFileCb)

const KB = process.env.KNOWLEDGE_BASE ?? ""
const OBSERVE = process.env.KNOWLEDGE_OBSERVE !== "0"

const warned = new Set<string>()

function warn(key: string, message: string): void {
	if (warned.has(key)) return
	warned.add(key)
	console.error(`knowledge extension: ${message}`)
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

type Content = string | Array<{ type: string; text?: string }> | undefined

function extractText(content: Content): string {
	if (typeof content === "string") return content
	if (!Array.isArray(content)) return ""
	return content
		.filter((block): block is { type: "text"; text: string } => block.type === "text")
		.map((block) => block.text)
		.join("\n")
}

export default function (pi: ExtensionAPI) {
	// No knowledge base configured: this machine does not want capture at all.
	if (!KB) return

	if (!existsSync(kbScript("session-init"))) {
		warn("missing", `KNOWLEDGE_BASE=${KB} has no scripts/session-init; capture disabled`)
		return
	}

	// One buffer per extension instance: pi reloads extensions per session,
	// so session replacement (new/resume/fork) tears this instance down via
	// session_shutdown and a fresh instance starts a fresh buffer.
	let bufferFile: string | undefined
	let sessionId = randomUUID()
	// Agent retries and branch replays can fire message_end for the same
	// message more than once; record what we have already appended.
	const appendedMessages = new Set<string>()
	// Cached for the life of the process on purpose: Claude Code injects KB
	// context once at SessionStart, and re-reading per turn would let the
	// instructions change underneath a running conversation.
	let contextCache: string | undefined

	async function initSession(id?: string): Promise<void> {
		if (id) sessionId = id
		if (bufferFile && existsSync(bufferFile)) return
		bufferFile =
			(await run(kbScript("session-init"), ["--session-id", sessionId])) || undefined
	}

	// The knowledge base sweeps buffers left idle for an hour, flushing and
	// deleting them. session-append no-ops silently on a missing file, so a
	// long-lived pi session whose buffer was swept would go deaf for the rest
	// of the run. Re-initialize instead.
	function bufferFor(): string | undefined {
		return bufferFile && existsSync(bufferFile) ? bufferFile : undefined
	}

	async function appendMessage(role: "user" | "assistant", message: string): Promise<void> {
		if (!OBSERVE || !message) return
		if (!bufferFor()) await initSession()
		const file = bufferFor()
		if (!file) return
		await run(kbScript("session-append"), [
			"--file",
			file,
			"--role",
			role,
			"--message",
			message,
		])
	}

	pi.on("session_start", async (_event, ctx) => {
		if (!OBSERVE) return
		const sessionFile = ctx.sessionManager.getSessionFile()
		// Ephemeral sessions get an in-process ID so quick one-off runs are
		// still captured; the file-based ID keeps /resume distinct per thread.
		const sessionId = sessionFile ? basename(sessionFile, extname(sessionFile)) : randomUUID()
		await initSession(sessionId)
	})

	pi.on("message_end", async (event) => {
		try {
			const { role } = event.message
			if (role !== "user" && role !== "assistant") return
			// Messages carry no id; the timestamp is stable across the retry
			// replays that re-fire this event for the same message.
			const key = `${role}:${event.message.timestamp}`
			if (appendedMessages.has(key)) return
			appendedMessages.add(key)
			// Text only, like the Claude and Codex shims: the transcript records
			// the conversation, not the tool traffic.
			const text = extractText(event.message.content)
			if (text) await appendMessage(role, text)
		} catch (error) {
			warn("message_end", `message_end handler failed: ${String(error)}`)
		}
	})

	pi.on("before_agent_start", async (event) => {
		try {
			if (contextCache === undefined) {
				contextCache = await run(kbScript("session-context"), [])
			}
			if (contextCache) {
				return { systemPrompt: `${event.systemPrompt}\n\n${contextCache}` }
			}
		} catch (error) {
			warn("before_agent_start", `context injection failed: ${String(error)}`)
		}
	})

	pi.on("session_shutdown", async () => {
		if (!OBSERVE) return
		const file = bufferFor()
		if (!file) return
		bufferFile = undefined
		await run(kbScript("session-flush"), [file], 15_000)
	})
}
