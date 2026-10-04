import { OAuthProvider } from "@cloudflare/workers-oauth-provider";
import { backendHeaders, resolveBackend } from "./backends";
import { GitHubHandler } from "./github-handler";
import { MCP_PATH, PROTECTED_RESOURCE_METADATA_PATH, servedOrigin } from "./hosts";

// Context from the auth process, encrypted & stored in the auth token
type Props = {
	login: string;
	name: string;
	email: string;
	accessToken: string;
};

const THIRTY_DAYS = 30 * 24 * 60 * 60;

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

function createProvider(origin: string) {
	return new OAuthProvider({
		apiRoute: MCP_PATH,
		apiHandler: mcpProxyHandler,
		authorizeEndpoint: "/authorize",
		clientRegistrationEndpoint: "/register",
		defaultHandler: GitHubHandler as any,
		tokenEndpoint: "/token",
		resourceMetadata: { resource: `${origin}${MCP_PATH}` },
		clientIdMetadataDocumentEnabled: true,
		clientRegistrationTTL: undefined,
		refreshTokenIdleTTL: THIRTY_DAYS,
	});
}

const providers = new Map<string, ReturnType<typeof createProvider>>();

function providerFor(origin: string) {
	let provider = providers.get(origin);
	if (!provider) {
		provider = createProvider(origin);
		providers.set(origin, provider);
	}
	return provider;
}

export default {
	fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> | Response {
		const url = new URL(request.url);
		const origin = servedOrigin(url);
		if (!origin) return new Response("Not found", { status: 404 });

		if (url.pathname === PROTECTED_RESOURCE_METADATA_PATH) {
			url.pathname = `${PROTECTED_RESOURCE_METADATA_PATH}${MCP_PATH}`;
			request = new Request(url, request);
		}

		// The provider caches its helpers on env.OAUTH_PROVIDER, so each host needs its own env object.
		return providerFor(origin).fetch(request, { ...env }, ctx);
	},
};
