#!/bin/bash

# Enrolls this Mac as a Teleport SSH resource against the current Kubernetes-hosted
# Teleport cluster, replacing any stale local agent left over from an earlier/different
# deployment (Teleport clusters don't share CAs or join tokens across reinstalls, so an
# old local agent config will never join a newer cluster and just blocks reinstallation).
#
# Requires sudo — Teleport installs a system-level launchd daemon, so this is meant to be
# run manually rather than wired into `terraform apply`.

set -e

NAMESPACE=${TELEPORT_NAMESPACE:-"homelab"}
DEPLOY=${TELEPORT_AUTH_DEPLOY:-"deploy/homelab-teleport-auth"}
PROXY=${TELEPORT_PROXY:-"tp.rainforest.tools:443"}

echo "=== Removing any stale local Teleport agent ==="
sudo pkill -f teleport 2>/dev/null || true
sudo rm -rf /var/lib/teleport
sudo rm -f /etc/teleport.yaml
if [ -f /Library/LaunchDaemons/com.goteleport.teleport.plist ]; then
  sudo launchctl unload /Library/LaunchDaemons/com.goteleport.teleport.plist 2>/dev/null || true
  sudo rm -f /Library/LaunchDaemons/com.goteleport.teleport.plist
fi
sudo rm -f /usr/local/bin/teleport /usr/local/bin/tctl /usr/local/bin/tsh /usr/local/bin/teleport-update

echo
echo "=== Generating a fresh join token against the current cluster ==="
echo "(Run the install command it prints below to complete enrollment.)"
echo
kubectl exec -n "$NAMESPACE" "$DEPLOY" -- tctl nodes add --ttl=10m
