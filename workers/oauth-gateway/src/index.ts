import OAuthProvider from "@cloudflare/workers-oauth-provider";
import { backendHeaders, resolveBackend } from "./backends";
import { GitHubHandler } from "./github-handler";

// Context from the auth process, encrypted & stored in the auth token
type Props = {
	login: string;
	name: string;
	email: string;
	accessToken: string;
};

// MCP Proxy Handler
const mcpProxyHandler = {
	async fetch(request: Request, env: any, ctx: ExecutionContext): Promise<Response> {
		const props = (ctx as any).props as Props;

		if (!props) {
			return new Response('Unauthorized - No user context', { status: 401 });
		}

		try {
			const url = new URL(request.url);
			const backend = resolveBackend(url.hostname, url.searchParams);
			const backendUrl = new URL(url.pathname + url.search, backend.url);

			const headers = backendHeaders(request.headers, backend, props, env);
			if (!(headers instanceof Headers)) {
				console.error(`[MCP Proxy] ${url.hostname}: ${headers.error}`);
				return new Response('Backend not configured', { status: 503 });
			}

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
