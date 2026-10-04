export const MCP_PATH = "/mcp";
export const PROTECTED_RESOURCE_METADATA_PATH = "/.well-known/oauth-protected-resource";

const PUBLIC_HOSTS = new Set([
	"docker-mcp.rainforest.tools",
	"calibre-mcp.rainforest.tools",
	"memories-mcp.rainforest.tools",
]);

const LOOPBACK_HOSTS = new Set(["localhost", "127.0.0.1", "[::1]"]);

export function servedOrigin(url: URL): string | null {
	if (url.protocol === "https:" && PUBLIC_HOSTS.has(url.hostname) && url.port === "") return url.origin;
	if (url.protocol === "http:" && LOOPBACK_HOSTS.has(url.hostname)) return url.origin;
	return null;
}
