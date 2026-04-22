import OAuthProvider from "@cloudflare/workers-oauth-provider";
import { GitHubHandler } from "./github-handler";

// Context from the auth process, encrypted & stored in the auth token
type Props = {
	login: string;
	name: string;
	email: string;
	accessToken: string;
};

// Backend routing: hostname-based first, then ?backend= query param fallback
const HOSTNAME_BACKENDS: Record<string, string> = {
	"obsidian": "https://obsidian-internal.rainforest.tools",
	"personal-calibre": "https://personal-calibre-internal.rainforest.tools",
};
const DEFAULT_BACKEND = "https://docker-mcp-internal.rainforest.tools";

function getBackendUrl(hostname: string, searchParams: URLSearchParams): string {
	// 1. Check hostname prefix (e.g. obsidian.rainforest.tools → "obsidian")
	const subdomain = hostname.split(".")[0];
	if (HOSTNAME_BACKENDS[subdomain]) {
		return HOSTNAME_BACKENDS[subdomain];
	}
	// 2. Check ?backend= query param (e.g. ?backend=obsidian)
	const backend = searchParams.get("backend");
	if (backend && HOSTNAME_BACKENDS[backend]) {
		return HOSTNAME_BACKENDS[backend];
	}
	return DEFAULT_BACKEND;
}

// MCP Proxy Handler
const mcpProxyHandler = {
	async fetch(request: Request, env: any, ctx: ExecutionContext): Promise<Response> {
		const props = (ctx as any).props as Props;

		if (!props) {
			return new Response('Unauthorized - No user context', { status: 401 });
		}

		try {
			const url = new URL(request.url);
			const backendBase = getBackendUrl(url.hostname, url.searchParams);
			const backendUrl = new URL(url.pathname + url.search, backendBase);

			const headers = new Headers(request.headers);
			headers.set('X-Forwarded-User', props.email);
			headers.set('X-Forwarded-Login', props.login);
			headers.set('X-GitHub-User', props.login);
			headers.set('X-GitHub-Token', props.accessToken);
			headers.delete('Authorization');

			console.log(`[MCP Proxy] ${request.method} ${url.hostname}${url.pathname} → ${backendUrl.toString()} (user: ${props.login})`);

			const response = await fetch(backendUrl.toString(), {
				method: request.method,
				headers,
				body: request.body,
			});

			return response;

		} catch (error) {
			console.error('[MCP Proxy] Error:', error);
			return new Response(`Proxy error: ${error instanceof Error ? error.message : String(error)}`, {
				status: 502,
				headers: { 'Content-Type': 'text/plain' }
			});
		}
	}
};

export default new OAuthProvider({
	apiHandlers: {
		"/sse": mcpProxyHandler,
		"/messages": mcpProxyHandler,
		"/message": mcpProxyHandler,
		"/mcp": mcpProxyHandler,
	},
	authorizeEndpoint: "/authorize",
	clientRegistrationEndpoint: "/register",
	defaultHandler: GitHubHandler as any,
	tokenEndpoint: "/token",
});
