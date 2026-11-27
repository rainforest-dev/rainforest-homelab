# pomodoro

Runs Bambii Focus (`ghcr.io/rainforest-dev/bambii-focus`) at `pomodoro.rainforest.tools`: one
Node 24 container that serves the web app and the partner-sync API, with its SQLite database on
the `pomodoro-data` volume at `/data`. The image is private and pinned by digest like the other
apps; the host's ghcr login pulls it.

Access: the page sits behind the same Access policy as the other family apps. The sync and push
routes (`/pair`, `/push`, `/healthz`) bypass Access through the tunnel module's `bypass_paths`,
because the native apps cannot carry an Access cookie; they are protected by the pairing itself
(device-signed requests, rate-limited pairing). See decision 0012 in the bambii-focus repo.

Web Push needs a VAPID key pair in `terraform.tfvars` (`pomodoro_vapid_public_key`,
`pomodoro_vapid_private_key`); without them push is off and everything else works.
