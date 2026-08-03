#!/usr/bin/env python3
"""TCP forwarder giving Docker containers a route to LAN services.

Why this exists
---------------
Docker Desktop containers on this Mac cannot reach the LAN: from inside a
container `ping 192.168.0.128` is 100% loss, while the host reaches it fine
over en1.

The cause is macOS Local Network privacy, not routing. This same script reaches
the Pi when started from an already-permitted shell and fails with
`[Errno 65] No route to host` under launchd, because a launchd-spawned process
is its own responsible process with no Local Network grant. Grant it in
System Settings -> Privacy & Security -> Local Network, and check the log:
without the grant this process still starts and binds, it just cannot connect
upstream.

Containers CAN reach `host.docker.internal`. So the host relays: a container
connects to `host.docker.internal:<local_port>` and this process forwards to
`<remote_host>:<remote_port>` on the LAN.

This is what makes the Docker MCP Gateway's `grafana` server work — its
container has to reach Grafana on the Raspberry Pi. Without the relay it gets
`dial tcp 192.168.0.128:30080: connect: connection refused`.

Usage: lan-forwarder.py <local_port> <remote_host> <remote_port>

Stdlib only, deliberately — this runs under launchd before any venv exists,
and adding a dependency would make the agent fail to start on a fresh machine.
"""
import socket
import sys
import threading

BUFSIZE = 65536
CONNECT_TIMEOUT = 10


def pipe(src, dst):
    """Relay bytes one direction until either side closes."""
    try:
        while True:
            data = src.recv(BUFSIZE)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        # Shut both halves down so the paired thread also unblocks.
        for sock in (src, dst):
            try:
                sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass


def handle(client, remote_host, remote_port):
    try:
        upstream = socket.create_connection(
            (remote_host, remote_port), timeout=CONNECT_TIMEOUT
        )
    except OSError as exc:
        print(f"upstream {remote_host}:{remote_port} unreachable: {exc}", flush=True)
        client.close()
        return
    threading.Thread(target=pipe, args=(client, upstream), daemon=True).start()
    threading.Thread(target=pipe, args=(upstream, client), daemon=True).start()


def main():
    if len(sys.argv) != 4:
        sys.exit(f"usage: {sys.argv[0]} <local_port> <remote_host> <remote_port>")

    local_port = int(sys.argv[1])
    remote_host = sys.argv[2]
    remote_port = int(sys.argv[3])

    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    # 0.0.0.0 so the Docker Desktop VM can reach it via host.docker.internal;
    # a 127.0.0.1 bind is not reachable from containers.
    listener.bind(("0.0.0.0", local_port))
    listener.listen(128)
    print(
        f"forwarding 0.0.0.0:{local_port} -> {remote_host}:{remote_port}",
        flush=True,
    )

    while True:
        conn, _ = listener.accept()
        threading.Thread(
            target=handle, args=(conn, remote_host, remote_port), daemon=True
        ).start()


if __name__ == "__main__":
    main()
