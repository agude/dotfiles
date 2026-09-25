import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui"

function displayDirectory(path: string): string {
	const home = process.env.HOME
	if (!home) return path
	if (path === home) return "~"
	return path.startsWith(`${home}/`) ? `~${path.slice(home.length)}` : path
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return

		ctx.ui.setFooter((_tui, theme) => ({
			render(width: number): string[] {
				const directory = displayDirectory(ctx.sessionManager.getCwd())
				const model = ctx.model?.id ?? "no-model"
				const percent = ctx.getContextUsage()?.percent
				const context = percent == null ? "?% context" : `${percent.toFixed(1)}% context`
				const padding = " ".repeat(Math.max(2, width - visibleWidth(model) - visibleWidth(context)))

				return [
					truncateToWidth(theme.fg("dim", directory), width),
					truncateToWidth(theme.fg("dim", `${model}${padding}${context}`), width),
				]
			},
		}))
	})
}
