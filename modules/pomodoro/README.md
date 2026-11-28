# pomodoro

Runs Bambii Focus (`ghcr.io/rainforest-dev/bambii-focus`) at `pomodoro.rainforest.tools`: one
Node 24 container that serves the web app and the partner-sync API, with its SQLite database on
the `pomodoro-data` volume at `/data`. The image is private, so unlike the other apps (public
images the provider pulls anonymously) the `docker` CLI pulls it with the host's ghcr login,
and the container is pinned to the ID of the image it pulled. To roll out a new release, run
`docker pull ghcr.io/rainforest-dev/bambii-focus:latest` before `terraform apply`, or apply with
`-replace=module.pomodoro.terraform_data.pull`.

Access: the page sits behind the same Access policy as the other family apps. The sync and push
routes (`/pair`, `/push`, `/healthz`) bypass Access through the tunnel module's `bypass_paths`,
because the native apps cannot carry an Access cookie; they are protected by the pairing itself
(device-signed requests, rate-limited pairing). See decision 0012 in the bambii-focus repo.

Web Push needs a VAPID key pair in `terraform.tfvars` (`pomodoro_vapid_public_key`,
`pomodoro_vapid_private_key`); without them push is off and everything else works.
