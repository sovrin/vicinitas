// Talks to the Vicinitas menu bar app over its Unix socket: newline-delimited JSON.
import { createConnection } from 'node:net'
import { mkdirSync, watch } from 'node:fs'
import { homedir } from 'node:os'
import { basename, dirname, join } from 'node:path'

const SOCKET = join(homedir(), 'Library/Application Support/Vicinitas/vicinitas.sock')

export class AppNotRunning extends Error {}

/** Sends one message; resolves with the first reply, the still-open socket, and a hook for later messages. */
function request(message) {
  return new Promise((resolve, reject) => {
    const sock = createConnection(SOCKET)
    let buffer = ''
    let onLater = null // set once the reply has arrived
    sock.on('data', (chunk) => {
      buffer += chunk
      for (let i; (i = buffer.indexOf('\n')) >= 0; ) {
        const line = buffer.slice(0, i)
        buffer = buffer.slice(i + 1)
        let parsed
        try {
          parsed = JSON.parse(line)
        } catch {
          continue
        }
        if (onLater) onLater(parsed)
        else {
          onLater = () => {}
          resolve({ reply: parsed, sock, onMessage: (fn) => (onLater = fn) })
        }
      }
    })
    sock.once('error', (err) =>
      reject(['ENOENT', 'ECONNREFUSED'].includes(err.code) ? new AppNotRunning('Vicinitas is not running') : err))
    sock.write(JSON.stringify(message) + '\n')
  })
}

/** One-shot command (add, rm, stop, list); resolves with the reply. Throws AppNotRunning, or an Error carrying the app's message. */
export async function command(message) {
  const { reply, sock } = await request(message)
  sock.end()
  if (!reply.ok) throw new Error(reply.error)
  return reply
}

/**
 * Keeps `entry` registered for as long as this process lives. The app drops the route when the
 * connection closes, so there is nothing to clean up. If the app isn't running or restarts, this
 * registers again as soon as its socket appears (a filesystem event, not polling).
 * Resolves after the first attempt: true if registered, false if the app isn't running; rejects on a refusal.
 */
export function stayRegistered(entry, { onStop, onLost, onRegistered }) {
  let connected = false
  let pending = false

  async function attempt() {
    if (connected || pending) return
    pending = true
    try {
      const { reply, sock, onMessage } = await request({ op: 'register', ...entry })
      if (!reply.ok) {
        sock.end()
        throw new Error(reply.error)
      }
      connected = true
      onMessage((message) => message.op === 'stop' && onStop())
      sock.on('close', () => {
        connected = false
        onLost()
      })
      sock.on('error', () => {})
      return true
    } catch (err) {
      if (err instanceof AppNotRunning) return false
      throw err
    } finally {
      pending = false
    }
  }

  mkdirSync(dirname(SOCKET), { recursive: true })
  watch(dirname(SOCKET), (_, file) => {
    if (file !== basename(SOCKET)) return
    attempt().then((ok) => ok && onRegistered(), (err) => console.error(`vicinitas: ${err.message}`))
  }).unref()

  return attempt()
}
