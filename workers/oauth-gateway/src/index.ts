import OAuthProvider from "@cloudflare/workers-oauth-provider";
import { GitHubHandler } from "./github-handler";

// Context from the auth process, encrypted & stored in the auth token
type Props = {
	login: string;
	name: string;
	email: string;
	accessToken: string;
};

const BACKEND_URL = "https://docker-mcp-internal.rainforest.tools";

// Docker MCP Proxy Handler
const dockerMCPHandler = {
	async fetch(request: Request, env: any, ctx: ExecutionContext): Promise<Response> {
		// The user props should be available via some mechanism from OAuthProvider
		// For now, we'll extract them from the context or use a different approach
		const props = (ctx as any).props as Props;
		
		if (!props) {
			return new Response('Unauthorized - No user context', { status: 401 });
		}

		try {
			// Build backend URL maintaining the original path structure
			const url = new URL(request.url);
			const backendUrl = new URL(url.pathname + url.search, BACKEND_URL);

			// Copy headers and add user information
			const headers = new Headers(request.headers);
			headers.set('X-Forwarded-User', props.email);
			headers.set('X-Forwarded-Login', props.login);
			headers.set('X-GitHub-User', props.login);
			headers.set('X-GitHub-Token', props.accessToken);
			headers.delete('Authorization'); // Remove OAuth headers before proxying

			// Add service token headers for Cloudflare Access authentication
			if (env.SERVICE_TOKEN_ID && env.SERVICE_TOKEN_SECRET) {
				headers.set('CF-Access-Client-Id', env.SERVICE_TOKEN_ID);
				headers.set('CF-Access-Client-Secret', env.SERVICE_TOKEN_SECRET);
			} else {
				console.warn(`[Docker MCP Proxy] WARNING: Service token credentials missing - authentication will fail`);
			}

			// Buffer the request body to handle potential redirects
			let body = null;
			if (request.body && request.method !== 'GET' && request.method !== 'HEAD') {
				body = await request.arrayBuffer();
			}

			const response = await fetch(backendUrl.toString(), {
				method: request.method,
				headers,
				body: body,
				redirect: 'manual', // Handle redirects manually to avoid body replay issues
			});

			// If we get a redirect, log it and return error (service token should prevent redirects)
			if (response.status >= 300 && response.status < 400) {
				const location = response.headers.get('Location');
				console.error(`[Docker MCP Proxy] Unexpected redirect to: ${location}`);
				console.error(`[Docker MCP Proxy] This means service token authentication failed!`);
				return new Response(`Service token authentication failed. Got redirect to: ${location}`, {
					status: 502,
					headers: { 'Content-Type': 'text/plain' }
				});
			}

			return response;

		} catch (error) {
			console.error('[Docker MCP Proxy] Error proxying request:', error);
			return new Response(`Proxy error: ${error instanceof Error ? error.message : String(error)}`, { 
				status: 502,
				headers: { 'Content-Type': 'text/plain' }
			});
		}
	}
};

export default new OAuthProvider({
	// Direct proxy to Docker MCP Gateway via Cloudflare Tunnel
	apiHandlers: {
		"/sse": dockerMCPHandler, // SSE protocol for Claude compatibility
		"/mcp": dockerMCPHandler, // Streamable-HTTP protocol (current standard)
	},
	authorizeEndpoint: "/authorize",
	clientRegistrationEndpoint: "/register",
	defaultHandler: GitHubHandler as any,
	tokenEndpoint: "/token",
});
