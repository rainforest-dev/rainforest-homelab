# ComfyUI (native / launchd)

Runs ComfyUI **natively** on the Mac Mini via a launchd agent (not Docker) so it can use
the Mac's **Metal (MPS) GPU** — Docker Desktop on macOS can't reach the GPU. Code lives in
the `server/` git submodule (upstream ComfyUI, unmodified).

## Local patches

Fixes to the vendored ComfyUI are kept as **tracked patch files in `patches/`**, never as
uncommitted edits inside the submodule. `null_resource.apply_patches` applies them
idempotently at deploy (skips if already applied, re-applies after a `git submodule update`),
and the submodule is set to `ignore = dirty` in `.gitmodules` so the applied patch doesn't
show up as a change in `git status` — while a real submodule *pointer* bump still does.

**Current patches:** `darwin27-psutil-compat.patch` — wraps `psutil.virtual_memory()` in a
try/except fallback so ComfyUI doesn't crash on Darwin 27 (psutil incompatibility).

**To add a patch:** edit the file in `server/`, run
`git -C server diff <file> > patches/<name>.patch`, then add it to `null_resource.apply_patches`.
