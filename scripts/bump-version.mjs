#!/usr/bin/env node
import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const kitDir = resolve(scriptDir, '..')
const versionPath = resolve(kitDir, 'VERSION')
const clientPath = resolve(kitDir, 'swift/Sources/ShipyardKit/ShipyardClient.swift')
const changelogPath = resolve(kitDir, 'CHANGELOG.md')

const bumpType = process.argv[2] ?? 'patch'
const current = readFileSync(versionPath, 'utf8').trim()
const match = current.match(/^(\d+)\.(\d+)\.(\d+)$/)
if (!match) {
  throw new Error(`VERSION must be semver x.y.z, got ${JSON.stringify(current)}`)
}

let [, majorRaw, minorRaw, patchRaw] = match
let major = Number(majorRaw)
let minor = Number(minorRaw)
let patch = Number(patchRaw)

switch (bumpType) {
  case 'major':
    major += 1
    minor = 0
    patch = 0
    break
  case 'minor':
    minor += 1
    patch = 0
    break
  case 'patch':
    patch += 1
    break
  default:
    throw new Error('Usage: node scripts/bump-version.mjs [patch|minor|major]')
}

const next = `${major}.${minor}.${patch}`
writeFileSync(versionPath, `${next}\n`)

const client = readFileSync(clientPath, 'utf8')
const updatedClient = client.replace(
  /public static let sdkVersion = "[^"]+"/,
  `public static let sdkVersion = "${next}"`,
)
if (client === updatedClient) {
  throw new Error('Could not find ShipyardClient.sdkVersion to update')
}
writeFileSync(clientPath, updatedClient)

const changelog = readFileSync(changelogPath, 'utf8')
const today = new Date().toISOString().slice(0, 10)
const entry = `\n## ${next} - ${today}\n\n- TODO: Describe SDK changes.\n`
const updatedChangelog = changelog.replace(/^# ShipyardKit Changelog\n/, `# ShipyardKit Changelog\n${entry}`)
writeFileSync(changelogPath, updatedChangelog)

console.log(`ShipyardKit ${current} -> ${next}`)
