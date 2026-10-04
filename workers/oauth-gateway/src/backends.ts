export type Backend = {
	url: string;
	forwardGithubToken: boolean;
	hostnameOnly?: boolean;
	gateway?: { header: string; secretEnv: string };
};

export type Identity = {
	login: string;
	email: string;
	accessToken: string;
};

export const BACKENDS: Record<string, Backend> = {
	obsidian: { url: "https://obsidian-internal.rainforest.tools", forwardGithubToken: true },
	calibre: { url: "https://personal-calibre-internal.rainforest.tools", forwardGithubToken: true },
	"calibre-mcp": { url: "https://personal-calibre-internal.rainforest.tools", forwardGithubToken: true },
	"memories-mcp": {
		url: "https://memories-mcp-internal.rainforest.tools",
		forwardGithubToken: false,
		hostnameOnly: true,
		gateway: { header: "x-memories-gateway", secretEnv: "MEMORIES_GATEWAY_SECRET" },
	},
};

export const DEFAULT_BACKEND: Backend = { url: "https://docker-mcp-internal.rainforest.tools", forwardGithubToken: true };

const IDENTITY_HEADERS = ["X-Forwarded-User", "X-Forwarded-Login", "X-GitHub-User", "X-GitHub-Token"];

export function resolveBackend(hostname: string, searchParams: URLSearchParams): Backend {
	const byHost = BACKENDS[hostname.split(".")[0]];
	if (byHost) return byHost;
	const named = searchParams.get("backend");
	const byQuery = named ? BACKENDS[named] : undefined;
	if (byQuery && !byQuery.hostnameOnly) return byQuery;
	return DEFAULT_BACKEND;
}

export function backendHeaders(
	incoming: Headers,
	backend: Backend,
	identity: Identity,
	env: Record<string, unknown>,
): Headers | { error: string } {
	const headers = new Headers(incoming);
	headers.delete("Authorization");
	for (const name of IDENTITY_HEADERS) headers.delete(name);
	for (const known of Object.values(BACKENDS)) {
		if (known.gateway) headers.delete(known.gateway.header);
	}

	headers.set("X-Forwarded-Login", identity.login);
	if (backend.forwardGithubToken) {
		headers.set("X-Forwarded-User", identity.email);
		headers.set("X-GitHub-User", identity.login);
		headers.set("X-GitHub-Token", identity.accessToken);
	}

	if (backend.gateway) {
		const secret = env[backend.gateway.secretEnv];
		if (typeof secret !== "string" || secret === "") {
			return { error: `${backend.gateway.secretEnv} is not configured` };
		}
		headers.set(backend.gateway.header, secret);
	}
	return headers;
}
