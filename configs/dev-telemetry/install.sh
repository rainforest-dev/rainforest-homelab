#!/usr/bin/env bash
# Install the dev-telemetry collectors on a Mac.
#
# Idempotent: re-running upgrades the config and restarts the agents.
# Touches nothing inside any git repository — see instrument-repo for that.
#
#   ./install.sh            install/upgrade and start
#   ./install.sh --verify   report status only, change nothing

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.config/dev-telemetry"
STATE="$HOME/.local/state/dev-telemetry"
AGENTS="$HOME/Library/LaunchAgents"
BREW="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
LABELS=(com.homelab.dev-node-exporter com.homelab.dev-alloy com.homelab.dev-ps-sampler)

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()  { printf '    \033[32m✓\033[0m %s\n' "$*"; }
bad() { printf '    \033[31m✗\033[0m %s\n' "$*"; }

verify() {
    say "launchd agents"
    # Snapshot the list once rather than piping it into grep per label.
    # `launchctl list | grep -q` is a false-negative trap under `set -o
    # pipefail`: grep -q exits on the first match, launchctl takes SIGPIPE
    # (141), and pipefail promotes that to the pipeline's status. Whether it
    # bites depends on how early the match appears in the stream, so it fails
    # for the first label and passes for the rest.
    local listing
    listing=$(launchctl list || true)
    for l in "${LABELS[@]}"; do
        case $listing in
            *"$l"*) ok "$l loaded" ;;
            *)      bad "$l NOT loaded" ;;
        esac
    done

    say "collectors"
    if curl -fsS --max-time 3 http://127.0.0.1:9100/metrics >/dev/null 2>&1; then
        ok "node_exporter responding ($(curl -fsS http://127.0.0.1:9100/metrics | grep -vc '^#') series)"
    else
        bad "node_exporter not responding on 127.0.0.1:9100"
    fi
    if curl -fsS --max-time 3 http://127.0.0.1:12345/-/ready >/dev/null 2>&1; then
        ok "alloy ready"
    else
        bad "alloy not ready on 127.0.0.1:12345"
    fi

    say "textfile collector"
    if [ -f "$STATE/textfile/dev_telemetry.prom" ]; then
        ok "$(grep -c '^dev_' "$STATE/textfile/dev_telemetry.prom") dev_* metrics written"
        grep -E '^dev_(vitest_workers|hooks_running)' "$STATE/textfile/dev_telemetry.prom" | sed 's/^/      /'
    else
        bad "no textfile output yet (sampler runs every 30s)"
    fi

    say "transport to the Pi"
    if curl -fsS --max-time 5 "http://raspberrypi-5:30090/-/healthy" >/dev/null 2>&1; then
        ok "Pi Prometheus reachable over the tailnet"
    else
        bad "Pi unreachable — is raspberrypi-5 on the tailnet? (tailscale status)"
    fi
}

if [ "${1:-}" = "--verify" ]; then verify; exit 0; fi

say "Installing Homebrew dependencies"
for pkg in node_exporter grafana-alloy; do
    if brew list "$pkg" >/dev/null 2>&1; then
        ok "$pkg already installed"
    else
        brew install "$pkg"
    fi
done

say "Creating directories"
mkdir -p "$DEST/bin" "$DEST/alloy" "$DEST/hooks" \
         "$STATE/textfile" "$STATE/running" "$STATE/alloy" \
         "$AGENTS" "$HOME/Library/Logs"
ok "$DEST"
ok "$STATE"

say "Installing scripts and config"
install -m 0755 "$SRC/bin/devlog"           "$DEST/bin/devlog"
install -m 0755 "$SRC/bin/ps-sampler"       "$DEST/bin/ps-sampler"
install -m 0755 "$SRC/bin/git-hook-wrapper" "$DEST/bin/git-hook-wrapper"
install -m 0755 "$SRC/bin/build-guard"       "$DEST/bin/build-guard"
install -m 0644 "$SRC/alloy/config.alloy"   "$DEST/alloy/config.alloy"
ok "scripts -> $DEST/bin"

# One shared hook directory that every instrumented repo points core.hooksPath
# at. Each entry is a symlink, so the wrapper reads its own basename to learn
# which hook it is standing in for.
for hook in pre-push pre-commit; do
    ln -sf "$DEST/bin/git-hook-wrapper" "$DEST/hooks/$hook"
done
ok "hook shims -> $DEST/hooks"

say "Installing launchd agents"
for l in "${LABELS[@]}"; do
    sed -e "s|__HOME__|$HOME|g" -e "s|__BREW__|$BREW|g" \
        "$SRC/launchd/$l.plist" > "$AGENTS/$l.plist"
done
ok "plists -> $AGENTS (with \$HOME=$HOME, brew=$BREW)"

say "Restarting agents"
# bootout + bootstrap, never kickstart: kickstart restarts from launchd's
# in-memory job definition and silently keeps running the OLD arguments.
#
# bootout returns before launchd has finished tearing the job down, so an
# immediate bootstrap loses a race and fails with the uninformative
# "Bootstrap failed: 5: Input/output error". Wait for the label to actually
# disappear, then retry a few times.
for l in "${LABELS[@]}"; do
    launchctl bootout "gui/$(id -u)/$l" 2>/dev/null || true

    for _ in $(seq 20); do
        launchctl list | grep -q "	$l\$" || break
        sleep 0.25
    done

    for attempt in 1 2 3 4 5; do
        if launchctl bootstrap "gui/$(id -u)" "$AGENTS/$l.plist" 2>/dev/null; then
            ok "$l"
            break
        fi
        [ "$attempt" -eq 5 ] && bad "$l failed to bootstrap after 5 attempts"
        sleep 1
    done
done

say "Waiting for collectors to come up"
sleep 6
verify
