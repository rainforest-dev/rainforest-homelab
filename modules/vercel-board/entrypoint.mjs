import { spawn } from 'node:child_process'
import { readdirSync, readFileSync, rmSync } from 'node:fs'
import net from 'node:net'
import { homedir } from 'node:os'
import { join } from 'node:path'
import { setTimeout as sleep } from 'node:timers/promises'

const BOARD_PORT = Number(process.env.BOARD_PORT ?? 4100)
const INSPECT_PORT = Number(process.env.INSPECT_PORT ?? 4747)
const ALLOW_HOSTS = (process.env.BOARD_ALLOW_HOSTS ?? '').split(',').filter(Boolean)
const API_PROXY_PORT = 4101
const INSPECT_PROXY_PORT = 4748

const CLI = 'node_modules/@vercel/board/dist/cli.mjs'
const TOKEN_DIR = join(homedir(), '.config/board/local')
const BOARD_URL = `http://127.0.0.1:${BOARD_PORT}/api/board`

for (const file of readdirSync(TOKEN_DIR).filter((name) => name.endsWith('.json'))) {
  try {
    if (JSON.parse(readFileSync(join(TOKEN_DIR, file), 'utf8')).url === BOARD_URL) rmSync(join(TOKEN_DIR, file))
  } catch {}
}

const children = []
const run = (args, env = process.env) => {
  const child = spawn(process.execPath, [CLI, ...args], { stdio: 'inherit', env })
  child.on('exit', (code) => {
    for (const other of children) if (other !== child) other.kill('SIGTERM')
    process.exit(code ?? 1)
  })
  children.push(child)
}
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => children.forEach((child) => child.kill(signal)))

// `vb serve` and `vb inspect` listen on 127.0.0.1 only, so each published or networked port is forwarded to them.
const forward = (from, to) =>
  net
    .createServer((client) => {
      const upstream = net.connect(to, '127.0.0.1')
      client.pipe(upstream).pipe(client)
      client.on('error', () => upstream.destroy())
      upstream.on('error', () => client.destroy())
    })
    .listen(from, '0.0.0.0')

run(['serve', '--no-open', '--no-inspect', '--port', String(BOARD_PORT), '--dir', '/data'])

const ready = async () => {
  for (let attempt = 0; attempt < 60; attempt++) {
    const token = readdirSync(TOKEN_DIR).some((file) => {
      try {
        return JSON.parse(readFileSync(join(TOKEN_DIR, file), 'utf8')).url === BOARD_URL
      } catch {
        return false
      }
    })
    if (token) return
    await sleep(500)
  }
  throw new Error(`no owner token for ${BOARD_URL}`)
}
await ready()

run(
  ['inspect', '--no-open', '--port', String(INSPECT_PORT), ...ALLOW_HOSTS.flatMap((host) => ['--allow-host', host])],
  { ...process.env, BOARD_URL },
)

forward(API_PROXY_PORT, BOARD_PORT)
forward(INSPECT_PROXY_PORT, INSPECT_PORT)
