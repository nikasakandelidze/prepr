#!/usr/bin/env node
// install-skills — copy the bundled Skill files into a Claude Code skills
// directory (user-level ~/.claude/skills by default, or --project for
// ./.claude/skills). Idempotent. Uses only Node core modules.

const fs = require('fs');
const path = require('path');
const os = require('os');

const PKG_ROOT = path.resolve(__dirname, '..');
const SKILLS_SRC = path.join(PKG_ROOT, 'skills');

function parseArgs(argv) {
  const opts = { scope: 'user', force: false, target: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--project') opts.scope = 'project';
    else if (a === '--user') opts.scope = 'user';
    else if (a === '--force' || a === '-f') opts.force = true;
    else if (a === '--target' && argv[i + 1]) { opts.target = argv[++i]; }
    else if (a === '-h' || a === '--help') {
      console.log(`install-skills — copy prepr Skill files into a Claude Code skills dir.

Usage:
  install-skills [--user | --project | --target DIR] [--force]

  --user      (default) install to ~/.claude/skills
  --project   install to ./.claude/skills (must run inside the target repo)
  --target D  install to D/prepr-*
  --force     overwrite existing skill dirs

Also symlinks bin/prepr into the same skills dir so the SKILL.md
references stay valid even without a global npm install.
`);
      process.exit(0);
    } else {
      console.error(`install-skills: unknown arg: ${a}`);
      process.exit(2);
    }
  }
  return opts;
}

function resolveTarget(opts) {
  if (opts.target) return path.resolve(opts.target);
  if (opts.scope === 'project') return path.resolve(process.cwd(), '.claude', 'skills');
  return path.join(os.homedir(), '.claude', 'skills');
}

function copyDir(src, dst, { force }) {
  if (fs.existsSync(dst)) {
    if (!force) {
      console.log(`  skip  ${path.basename(dst)} (exists — pass --force to overwrite)`);
      return false;
    }
    fs.rmSync(dst, { recursive: true, force: true });
  }
  fs.mkdirSync(dst, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, entry.name);
    const d = path.join(dst, entry.name);
    if (entry.isDirectory()) copyDir(s, d, { force: true });
    else fs.copyFileSync(s, d);
  }
  console.log(`  wrote ${path.basename(dst)}`);
  return true;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const target = resolveTarget(opts);
  fs.mkdirSync(target, { recursive: true });

  console.log(`Installing prepr skills → ${target}`);
  for (const name of fs.readdirSync(SKILLS_SRC)) {
    const src = path.join(SKILLS_SRC, name);
    if (!fs.statSync(src).isDirectory()) continue;
    copyDir(src, path.join(target, name), opts);
  }

  // Symlink the CLI next to the skills, so agents can find it via a stable
  // relative path even when the package isn't on $PATH globally.
  const binSrc = path.join(PKG_ROOT, 'bin', 'prepr');
  const binDst = path.join(target, 'prepr');
  try {
    if (fs.existsSync(binDst) || fs.lstatSync(binDst, { throwIfNoEntry: false })) {
      fs.rmSync(binDst, { force: true });
    }
  } catch (_) { /* not present */ }
  try {
    fs.symlinkSync(binSrc, binDst);
    console.log(`  linked prepr → ${binSrc}`);
  } catch (e) {
    // Windows / restricted FS: fall back to a copy.
    fs.copyFileSync(binSrc, binDst);
    fs.chmodSync(binDst, 0o755);
    console.log(`  copied prepr (symlink not available: ${e.code})`);
  }

  console.log(`\nDone. Restart Claude Code (or /reload skills) to pick them up.`);
  console.log(`Verify with:   prepr --help`);
}

main();
