import type { AuthRequest, OAuthHelpers } from "@cloudflare/workers-oauth-provider";
import { Hono } from "hono";
import { Octokit } from "octokit";
import { fetchUpstreamAuthToken, getUpstreamAuthorizeUrl, type Props } from "./utils";
import {
	clientIdAlreadyApproved,
	parseRedirectApproval,
	renderApprovalDialog,
} from "./workers-oauth-utils";

// Extended Env interface with GitHub OAuth secrets
interface ExtendedEnv {
	GITHUB_CLIENT_ID: string;
	GITHUB_CLIENT_SECRET: string;  
	COOKIE_ENCRYPTION_KEY: string;
	OAUTH_PROVIDER: OAuthHelpers;
}

const app = new Hono<{ Bindings: ExtendedEnv }>();

app.get("/authorize", async (c) => {
	try {
		// Parse OAuth request - this can throw various OAuth-related exceptions
		let oauthReqInfo;
		try {
			oauthReqInfo = await c.env.OAUTH_PROVIDER.parseAuthRequest(c.req.raw);
		} catch (error) {
			console.error("[OAuth] Failed to parse authorization request:", error);
			const errorMessage = error instanceof Error ? error.message : String(error);
			
			// Handle common OAuth errors
			if (errorMessage.includes("Invalid redirect URI")) {
				return c.json({
					error: "invalid_request",
					error_description: "Invalid redirect URI. The redirect URI provided does not match any registered URI for this client.",
					hint: "Ensure the redirect_uri matches exactly what was registered with the OAuth client"
				}, 400);
			} else if (errorMessage.includes("Invalid client")) {
				return c.json({
					error: "invalid_client",
					error_description: "Invalid client. The client ID provided is not recognized.",
					hint: "Use POST /register to register a new OAuth client"
				}, 404);
			} else {
				return c.json({
					error: "invalid_request",
					error_description: "Invalid authorization request",
					details: errorMessage
				}, 400);
			}
		}
		
		const { clientId } = oauthReqInfo;
		
		if (!clientId) {
			return c.json({
				error: "invalid_request",
				error_description: "Missing required parameter: client_id"
			}, 400);
		}

		// Proper error handling for client lookup
		let client;
		try {
			client = await c.env.OAUTH_PROVIDER.lookupClient(clientId);
			if (!client) {
				throw new Error("Client not found");
			}
		} catch (error) {
			console.error(`[OAuth] Client lookup failed for ${clientId}:`, error);
			return c.json({
				error: "invalid_client",
				error_description: `Client ID '${clientId}' not found. Please ensure the client is registered with the OAuth provider.`,
				hint: "Use POST /register to register a new OAuth client"
			}, 404);
		}

		if (
			await clientIdAlreadyApproved(c.req.raw, oauthReqInfo.clientId, c.env.COOKIE_ENCRYPTION_KEY)
		) {
			return redirectToGithub(c.req.raw, oauthReqInfo, c.env);
		}

		return renderApprovalDialog(c.req.raw, {
			client: client,
			server: {
				description: "Docker MCP Gateway with GitHub OAuth authentication. Provides secure access to Docker containers, images, networks, and volumes via MCP tools.",
				logo: "https://avatars.githubusercontent.com/u/5429470?s=200&v=4",
				name: "Docker MCP Gateway",
			},
			state: { oauthReqInfo },
		});
	} catch (error) {
		console.error("[OAuth] Authorization endpoint error:", error);
		return c.json({
			error: "server_error",
			error_description: "Internal server error during authorization request",
			details: error instanceof Error ? error.message : String(error)
		}, 500);
	}
});

app.post("/authorize", async (c) => {
	try {
		// Check if COOKIE_ENCRYPTION_KEY is properly configured
		if (!c.env.COOKIE_ENCRYPTION_KEY) {
			console.error("[OAuth] COOKIE_ENCRYPTION_KEY is not configured");
			return c.json({
				error: "server_error",
				error_description: "OAuth service configuration error - missing cookie encryption key",
				hint: "Administrator needs to configure COOKIE_ENCRYPTION_KEY secret"
			}, 500);
		}

		// Validates form submission, extracts state, and generates Set-Cookie headers to skip approval dialog next time
		const { state, headers } = await parseRedirectApproval(c.req.raw, c.env.COOKIE_ENCRYPTION_KEY);
		if (!state.oauthReqInfo) {
			return c.json({
				error: "invalid_request",
				error_description: "Invalid approval request - missing OAuth state"
			}, 400);
		}

		return redirectToGithub(c.req.raw, state.oauthReqInfo, c.env, headers);
	} catch (error) {
		console.error("[OAuth] Authorization approval error:", error);
		const errorMessage = error instanceof Error ? error.message : String(error);
		
		// Handle specific OAuth approval errors
		if (errorMessage.includes("COOKIE_SECRET is not defined") || errorMessage.includes("missing cookie encryption key")) {
			return c.json({
				error: "server_error",
				error_description: "OAuth service configuration error - cookie encryption not properly configured",
				hint: "Administrator needs to set COOKIE_ENCRYPTION_KEY secret"
			}, 500);
		} else if (errorMessage.includes("Invalid request method")) {
			return c.json({
				error: "invalid_request",
				error_description: "Invalid request method for authorization approval"
			}, 405);
		} else if (errorMessage.includes("Missing or invalid 'state'")) {
			return c.json({
				error: "invalid_request",
				error_description: "Missing or invalid state parameter in approval form"
			}, 400);
		} else {
			return c.json({
				error: "server_error",
				error_description: "Internal server error during authorization approval",
				details: errorMessage
			}, 500);
		}
	}
});

async function redirectToGithub(
	request: Request,
	oauthReqInfo: AuthRequest,
	env: ExtendedEnv,
	headers: Record<string, string> = {},
) {
	return new Response(null, {
		headers: {
			...headers,
			location: getUpstreamAuthorizeUrl({
				client_id: env.GITHUB_CLIENT_ID,
				redirect_uri: new URL("/callback", request.url).href,
				scope: "read:user",
				state: btoa(JSON.stringify(oauthReqInfo)),
				upstream_url: "https://github.com/login/oauth/authorize",
			}),
		},
		status: 302,
	});
}

/**
 * OAuth Callback Endpoint
 *
 * This route handles the callback from GitHub after user authentication.
 * It exchanges the temporary code for an access token, then stores some
 * user metadata & the auth token as part of the 'props' on the token passed
 * down to the client. It ends by redirecting the client back to _its_ callback URL
 */
app.get("/callback", async (c) => {
	try {
		// Validate state parameter
		const stateParam = c.req.query("state");
		if (!stateParam) {
			return c.json({
				error: "invalid_request",
				error_description: "Missing required parameter: state"
			}, 400);
		}

		// Parse OAuth request info from state
		let oauthReqInfo: AuthRequest;
		try {
			oauthReqInfo = JSON.parse(atob(stateParam)) as AuthRequest;
		} catch (error) {
			console.error("[OAuth] Invalid state parameter:", error);
			return c.json({
				error: "invalid_request", 
				error_description: "Invalid state parameter - unable to decode"
			}, 400);
		}

		if (!oauthReqInfo.clientId) {
			return c.json({
				error: "invalid_request",
				error_description: "Invalid state - missing client_id"
			}, 400);
		}

		// Validate authorization code
		const authCode = c.req.query("code");
		if (!authCode) {
			return c.json({
				error: "invalid_request",
				error_description: "Missing authorization code from GitHub"
			}, 400);
		}

		// Exchange the code for an access token
		console.log(`[OAuth] Exchanging authorization code for access token (client: ${oauthReqInfo.clientId})`);
		const [accessToken, errResponse] = await fetchUpstreamAuthToken({
			client_id: c.env.GITHUB_CLIENT_ID,
			client_secret: c.env.GITHUB_CLIENT_SECRET,
			code: authCode,
			redirect_uri: new URL("/callback", c.req.url).href,
			upstream_url: "https://github.com/login/oauth/access_token",
		});

		if (errResponse) {
			console.error("[OAuth] GitHub token exchange failed:", errResponse.status, errResponse.statusText);
			return c.json({
				error: "access_denied",
				error_description: "Failed to exchange authorization code for access token",
				github_error: errResponse.statusText
			}, 401);
		}

		if (!accessToken) {
			console.error("[OAuth] No access token received from GitHub");
			return c.json({
				error: "access_denied",
				error_description: "GitHub returned empty access token"
			}, 401);
		}

		// Fetch the user info from GitHub
		console.log("[OAuth] Fetching GitHub user information");
		let user;
		try {
			const octokit = new Octokit({ auth: accessToken });
			user = await octokit.rest.users.getAuthenticated();
		} catch (error) {
			console.error("[OAuth] Failed to fetch GitHub user info:", error);
			return c.json({
				error: "server_error",
				error_description: "Failed to fetch user information from GitHub",
				details: error instanceof Error ? error.message : String(error)
			}, 502);
		}

		const { login, name, email } = user.data;
		console.log(`[OAuth] GitHub user authenticated: ${login} (${email})`);

		// Return back to the MCP client a new token
		try {
			const { redirectTo } = await c.env.OAUTH_PROVIDER.completeAuthorization({
				metadata: {
					label: name || login,
				},
				props: {
					accessToken,
					email: email || "",
					login,
					name: name || login,
				} as Props,
				request: oauthReqInfo,
				scope: oauthReqInfo.scope,
				userId: login,
			});

			console.log(`[OAuth] Redirecting to: ${redirectTo}`);
			return Response.redirect(redirectTo);
		} catch (error) {
			console.error("[OAuth] Failed to complete authorization:", error);
			return c.json({
				error: "server_error", 
				error_description: "Failed to complete OAuth authorization flow",
				details: error instanceof Error ? error.message : String(error)
			}, 500);
		}
	} catch (error) {
		console.error("[OAuth] Callback endpoint error:", error);
		return c.json({
			error: "server_error",
			error_description: "Internal server error during OAuth callback",
			details: error instanceof Error ? error.message : String(error)
		}, 500);
	}
});

export { app as GitHubHandler };
