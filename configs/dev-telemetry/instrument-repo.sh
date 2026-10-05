#!/usr/bin/env bash
# Point a repository's git hooks at the telemetry wrapper.
#
#   ./instrument-repo.sh /path/to/repo      instrument
#   ./instrument-repo.sh /path/to/repo -u   remove instrumentation
#
# NOTHING IS COMMITTED. The only change is `git config --local core.hooksPath`,
# which lives in .git/config — a file git does not track. The wrapper scripts
# live outside the repository entirely. After running this, `git status` in the
# target repo is unchanged.
#
# core.hooksPath is stored in the repository's common config, so a single run
# covers every linked worktree. That sharing is also precisely why the hooks
# contend with each other in the first place.

set -euo pipefail

DEST="$HOME/.config/dev-telemetry"
REPO="${1:-$PWD}"
MODE="${2:-install}"

cd "$REPO"
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo: $REPO" >&2; exit 1; }
COMMON=$(git rev-parse --path-format=absolute --git-common-dir)

if [ "$MODE" = "-u" ] || [ "$MODE" = "--uninstall" ]; then
    # Worktree-scoped overrides first: they win over the repo-level value, so
    # restoring only the repo level would leave them pointing at a wrapper that
    # is about to be deleted.
    git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10)}' | while read -r wt; do
        [ -d "$wt" ] || continue
        WT_ORIG=$(git -C "$wt" config --worktree --get telemetry.originalHooksPath 2>/dev/null || echo "")
        [ -n "$WT_ORIG" ] || continue
        git -C "$wt" config --worktree core.hooksPath "$WT_ORIG" 2>/dev/null || true
        git -C "$wt" config --worktree --unset telemetry.originalHooksPath 2>/dev/null || true
        echo "restored worktree: $wt -> $WT_ORIG"
    done

    ORIG=$(git config --local --get telemetry.originalHooksPath || echo "")
    if [ -n "$ORIG" ]; then
        git config --local core.hooksPath "$ORIG"
        git config --local --unset telemetry.originalHooksPath
        echo "restored core.hooksPath -> $ORIG"
    else
        git config --local --unset core.hooksPath 2>/dev/null || true
        echo "unset core.hooksPath (there was no saved original)"
    fi
    exit 0
fi

[ -x "$DEST/bin/git-hook-wrapper" ] || { echo "run install.sh first" >&2; exit 1; }

CURRENT=$(git config --local --get core.hooksPath || echo "")

if [ "$CURRENT" = "$DEST/hooks" ]; then
    echo "already instrumented"
else
    # Save whatever was there — husky v9 sets this to .husky/_ and overwriting
    # it without a record would quietly disable the project's real hooks.
    if [ -n "$CURRENT" ]; then
        git config --local telemetry.originalHooksPath "$CURRENT"
        echo "saved original core.hooksPath: $CURRENT"
    elif [ -d .husky ]; then
        git config --local telemetry.originalHooksPath ".husky"
        echo "no core.hooksPath set; detected husky, saved .husky"
    else
        git config --local telemetry.originalHooksPath "$COMMON/hooks"
        echo "no core.hooksPath set; saved default $COMMON/hooks"
    fi
    git config --local core.hooksPath "$DEST/hooks"
    echo "core.hooksPath -> $DEST/hooks"
fi

# Worktree-scoped overrides.
#
# With extensions.worktreeConfig enabled, a worktree's own config.worktree can
# carry its own core.hooksPath, and that WINS over the repo-level value set
# above. service-dashboard-frontend has 27 such worktrees (agent-created ones
# get an absolute path to the main clone's .husky/_). Instrumenting only the
# repo level would silently miss every one of them — and they are precisely the
# worktrees that push concurrently, so the gap would hide the contention this
# whole exercise exists to measure.
echo
echo "worktree-scoped core.hooksPath overrides:"
OVERRIDDEN=0
git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10)}' | while read -r wt; do
    [ -d "$wt" ] || continue
    WT_HOOKS=$(git -C "$wt" config --worktree --get core.hooksPath 2>/dev/null || echo "")
    [ -n "$WT_HOOKS" ] || continue
    [ "$WT_HOOKS" = "$DEST/hooks" ] && continue
    git -C "$wt" config --worktree telemetry.originalHooksPath "$WT_HOOKS" 2>/dev/null || continue
    git -C "$wt" config --worktree core.hooksPath "$DEST/hooks" 2>/dev/null || continue
    OVERRIDDEN=$((OVERRIDDEN + 1))
    echo "  redirected: $wt"
done
echo "  (worktrees without their own override inherit the repo-level setting)"

echo
echo "verification:"
echo "  core.hooksPath          = $(git config --local --get core.hooksPath)"
echo "  originalHooksPath       = $(git config --local --get telemetry.originalHooksPath)"
printf '  working tree clean?      '
if [ -z "$(git status --porcelain)" ]; then echo "yes — nothing was committed or staged"; else echo "NO (pre-existing changes, not from this script)"; fi
