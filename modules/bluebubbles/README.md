# bluebubbles

Installs [BlueBubbles Server](https://bluebubbles.app/) on this Mac so Hermes Agent's `bluebubbles`
platform can send and receive iMessage. Hermes calls the server at `127.0.0.1:1234`; the server
posts new messages to Hermes's webhook at `127.0.0.1:8645`, which Hermes registers itself.

Terraform downloads the pinned arm64 DMG from the GitHub release, checks its SHA-256, copies the
app into `/Applications` and checks its signature and notarization. The Homebrew cask is not used:
it is stuck on 1.9.9, which Homebrew disabled for failing Gatekeeper on 2026-09-01. 1.9.11 and
later are notarized again.

Everything else is in the app's GUI, which no CLI or config file drives.

## Setup

1. Sign Messages on this Mac into the Apple ID the agent should use. The server can read every
   message on that account, and Hermes receives every one of them through the webhook. The
   allowlist only limits who Hermes answers.
2. `enable_bluebubbles = true` in `terraform.tfvars`, then `terraform apply`.
3. Open BlueBubbles and finish its wizard:
   - grant Full Disk Access and Accessibility when asked;
   - Settings → Connection: port `1234`, password from `terraform output -raw bluebubbles_password`;
   - Proxy Service: **Dynamic DNS / LAN**. Hermes is on this Mac, so no Cloudflare, Ngrok or Zrok
     proxy is needed, and one would put the API on the internet;
   - turn on Startup with macOS, and skip the Firebase/Google sign-in (only the BlueBubbles
     phone apps need it).
4. Append the Hermes credentials and restart the gateway:
   ```bash
   terraform output -raw bluebubbles_hermes_env >> ~/.hermes/.env
   echo 'BLUEBUBBLES_ALLOWED_USERS=<your phone or Apple ID>' >> ~/.hermes/.env
   launchctl kickstart -k gui/$(id -u)/ai.hermes.gateway
   ```
   This needs a Hermes with the `bluebubbles` platform plugin (v0.22.x).
5. Check `hermes logs gateway` for `[bluebubbles] connected to http://127.0.0.1:1234` and
   `webhook registered with server`, then text the agent's Apple ID from your phone.

## Exposure

The server listens on every interface, so `:1234` is reachable from the LAN, guarded by its
password. To keep it on loopback, block incoming connections for BlueBubbles in System Settings →
Network → Firewall → Options; loopback traffic from Hermes is not affected.

## Upgrade

Set `app_version` and `dmg_sha256` (the `digest` of the arm64 DMG on the release page,
`gh release view v<version> -R BlueBubblesApp/bluebubbles-server --json assets`) and apply. The
app's own Install Update also works, and Terraform then reinstalls the pinned version only when
those two variables change.
