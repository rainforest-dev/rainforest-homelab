import { spawn } from 'node:child_process'
import { readdirSync, readFileSync, rmSync } from 'node:fs'
import net from 'node:net'
import { homedir } from 'node:os'
import { join } from 'node:path'

const BOARD_PORT = Number(process.env.BOARD_PORT ?? 4100)
const PROXY_PORT = Number(process.env.PROXY_PORT ?? 4101)
const ALLOW_HOSTS = (process.env.BOARD_ALLOW_HOSTS ?? '').split(',').filter(Boolean)

const TOKEN_DIR = join(homedir(), '.config/board/local')
const BOARD_URL = `http://127.0.0.1:${BOARD_PORT}/api/board`

for (const file of readdirSync(TOKEN_DIR).filter((name) => name.endsWith('.json'))) {
  try {
    if (JSON.parse(readFileSync(join(TOKEN_DIR, file), 'utf8')).url === BOARD_URL) rmSync(join(TOKEN_DIR, file))
  } catch {}
}

const args = [
  'node_modules/@vercel/board/dist/cli.mjs',
  'serve',
  '--no-open',
  '--port',
  String(BOARD_PORT),
  '--dir',
  '/data',
  ...ALLOW_HOSTS.flatMap((host) => ['--allow-host', host]),
]

const board = spawn(process.execPath, args, { stdio: 'inherit' })
board.on('exit', (code) => process.exit(code ?? 1))
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => board.kill(signal))

// `vb serve` listens on 127.0.0.1 only, so the published port is forwarded to it from inside the container.
net
  .createServer((client) => {
    const upstream = net.connect(BOARD_PORT, '127.0.0.1')
    client.pipe(upstream).pipe(client)
    client.on('error', () => upstream.destroy())
    upstream.on('error', () => client.destroy())
  })
  .listen(PROXY_PORT, '0.0.0.0')
