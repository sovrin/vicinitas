#!/usr/bin/env node
// vici [--name <name>] <command...>  run <command> on a free port as <name>.localhost
// vici add <name> <port>             fixed route to a server started some other way
// vici rm <name>                     remove a fixed route
// vici ls                            list routes
// vici open [name]                   open a route in the browser (default: this project)
// vici stop [name]                   stop a running dev server (default: this project)
//
// Registers with the Vicinitas menu bar app over its socket (see client.mjs).
import { spawn, execFileSync } from 'node:child_process'
import { createServer } from 'node:net'
import { readFileSync } from 'node:fs'
import { basename } from 'node:path'
import { homedir } from 'node:os'
import { command, stayRegistered, AppNotRunning } from './client.mjs'

const USAGE = `usage: vici [--name <name>] <command...>
       vici add <name> <port>
       vici rm <name>
       vici ls
       vici open [name]
       vici stop [name]`
const tag = '\x1b[36mvicinitas\x1b[0m'

const args = process.argv.slice(2)
try {
  if (args[0] === 'add') await add(args[1], args[2])
  else if (args[0] === 'rm') await remove(args[1])
  else if (args[0] === 'ls') await list()
  else if (args[0] === 'open') open(args[1])
  else if (args[0] === 'stop') await stop(args[1])
  else await run(args)
} catch (err) {
  fail(err instanceof AppNotRunning ? 'Vicinitas is not running, open Vicinitas.app first' : err.message)
}

async function run(args) {
  let name
  if (args[0] === '--name') name = args.splice(0, 2)[1]
  if (!args.length) fail(USAGE)

  name = nameOr(name)

  const port = Number(process.env.PORT) || (await freePort())
  let child
  const registered = await stayRegistered(
    { name, port, cwd: process.cwd() },
    {
      onStop: () => child?.kill('SIGINT'), // the menu bar app's stop button
      onLost: () => console.error(`${tag} app quit, ${name}.localhost is offline until it restarts`),
      onRegistered: () => console.error(`${tag} → http://${name}.localhost  (registered again)`),
    },
  )
  console.log(registered
    ? `${tag} → http://${name}.localhost  (port ${port})`
    : `${tag} app not running, registers ${name}.localhost when it starts  (port ${port})`)

  child = spawn(args[0], args.slice(1), {
    stdio: 'inherit',
    env: { ...process.env, PORT: String(port), NUXT_PORT: String(port) },
  })
  for (const sig of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(sig, () => child.kill(sig))
  child.on('error', (err) => fail(err.message))
  child.on('exit', (code) => process.exit(code ?? 1))
}

async function add(rawName, rawPort) {
  const name = cleanName(rawName ?? '')
  const port = Number(rawPort)
  if (!name || !Number.isInteger(port) || port < 1 || port > 65535) fail(USAGE)
  await command({ op: 'add', name, port })
  console.log(`${tag} → http://${name}.localhost  (fixed, port ${port})`)
}

async function remove(rawName) {
  const name = cleanName(rawName ?? '')
  if (!name) fail(USAGE)
  await command({ op: 'rm', name })
  console.log(`removed ${name}.localhost`)
}

async function list() {
  const { routes } = await command({ op: 'list' })
  if (!routes.length) return console.log('no routes')
  const width = Math.max(...routes.map((r) => r.host.length))
  for (const r of routes) {
    const where = r.fixed ? 'fixed' : r.cwd.replace(homedir(), '~')
    console.log(`${('http://' + r.host).padEnd(width + 9)}${(':' + r.port).padEnd(8)}${where}`)
  }
}

function open(rawName) {
  spawn('open', [`http://${nameOr(rawName)}.localhost`], { stdio: 'inherit' })
}

async function stop(rawName) {
  const name = nameOr(rawName)
  await command({ op: 'stop', name })
  console.log(`stopping ${name}.localhost`)
}

/** `raw` cleaned, or this project's default name. */
function nameOr(raw) {
  // In a linked git worktree, prefix with its folder: archerfish.sonotas.localhost
  const name = cleanName(raw ?? [worktree(), pkgName() ?? basename(process.cwd())].filter(Boolean).join('.'))
  if (!name) fail('could not derive a valid name, pass one')
  return name
}

/** Lowercase DNS labels joined by dots; npm scope dropped. Empty string if nothing valid is left. */
function cleanName(name) {
  return name
    .replace(/^@[^/]+\//, '')
    .toLowerCase()
    .split('.')
    .map((label) => label.replace(/[^a-z0-9-]+/g, '-').replace(/^-+|-+$/g, ''))
    .filter(Boolean)
    .join('.')
}

/** Folder name of the current linked git worktree, or undefined in a main checkout. */
function worktree() {
  try {
    const [top, gitDir, commonDir] = execFileSync(
      'git',
      ['rev-parse', '--path-format=absolute', '--show-toplevel', '--git-dir', '--git-common-dir'],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] },
    ).trim().split('\n')
    return gitDir !== commonDir ? basename(top) : undefined
  } catch {}
}

function pkgName() {
  try {
    return JSON.parse(readFileSync('package.json', 'utf8')).name
  } catch {}
}

function freePort() {
  return new Promise((resolve, reject) => {
    const srv = createServer()
      .on('error', reject)
      .listen(0, '127.0.0.1', () => {
        const { port } = srv.address()
        srv.close(() => resolve(port))
      })
  })
}

function fail(message) {
  console.error(message.startsWith('usage') ? message : `vicinitas: ${message}`)
  process.exit(1)
}
