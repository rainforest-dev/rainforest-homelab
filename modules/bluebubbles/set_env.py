import os
import sys

path = sys.argv[1]
updates = dict(line.split("=", 1) for line in sys.stdin.read().splitlines() if line)

lines = []
if os.path.exists(path):
    with open(path) as f:
        lines = f.read().splitlines()

seen = set()
out = []
for line in lines:
    key = line.split("=", 1)[0]
    if key in updates:
        if key not in seen:
            out.append(f"{key}={updates[key]}")
            seen.add(key)
        continue
    out.append(line)
out += [f"{k}={v}" for k, v in updates.items() if k not in seen]

tmp = f"{path}.tmp"
fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w") as f:
    f.write("\n".join(out) + "\n")
os.replace(tmp, path)
