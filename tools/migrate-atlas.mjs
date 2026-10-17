#!/usr/bin/env node
// Derives this kit's `atlas` global pack tree from the Claude kit's atlas pack
// (decision brief D-3): the Commands, their scripts and the vendored skills are
// converted by a defined text transform, never edited by hand. Re-run it after a
// Command-text fix in the Claude kit (or after its T048 Commands merge), then
// `node tools/sync-assets.mjs` and `python3 tools/refresh-pack-digests.py`.
//
//   node tools/migrate-atlas.mjs <claude-kit-checkout> [--out <pack-dir>]
//
// This is not the whole-kit importer (migrate-source.mjs, which must never be
// rerun over native adaptations): it writes only global/.agents/skills of the
// atlas pack, the generated agents/openai.yaml files and source-map.json. The
// pack notes and pack.yaml are native.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
const args = process.argv.slice(2);
const outFlag = args.indexOf('--out');
const outDir = outFlag >= 0 ? path.resolve(args.splice(outFlag, 2)[1]) : path.join(root, 'assets/packs/atlas');
if (!args[0]) { console.error('usage: migrate-atlas.mjs <claude-kit-checkout> [--out <pack-dir>]'); process.exit(2); }
const sourceKit = path.resolve(args[0]);
const sourceSkills = path.join(sourceKit, 'assets/packs/atlas/global/.claude/skills');
if (!fs.existsSync(sourceSkills)) { console.error(`not a Claude kit with an atlas pack: ${sourceKit}`); process.exit(2); }

// The 16 Commands of the roster; a Command not yet in the source kit is skipped.
const ROSTER = ['map-repo', 'map-ask', 'map-impact', 'diagram', 'diagram-repo', 'diagram-flow', 'atlas-doctor',
  'rea-doctor', 'rea-triage', 'rea-feature', 'rea-binary', 'rea-android', 'rea-electron', 'rea-diagram', 'rea-map', 'rea-update'];
// Other kit skills the Command text names; `/name` becomes `$name` for all of them.
const OTHER_SKILLS = ['session-start', 'session-wrapup', 'session-checkpoint', 'refine-beads', 'grill-with-docs',
  'plan-to-beads-unified', 'product-architect', 'project-planner', 'brainstormer', 'tdd', 'falcon', 'herald'];
const VENDORED = ['archify', 'graphify'];
const AGENTS_DIR = '$HOME/.agents';

const fail = message => { throw new Error(message); };
function exactly(text, from, to, where, count = 1) {
  const found = text.split(from).length - 1;
  if (found !== count) fail(`${where}: expected ${count} match(es) of ${JSON.stringify(from.slice(0, 90))}, found ${found}`);
  return text.split(from).join(to);
}
function between(text, start, end, to, where) {
  const a = text.indexOf(start);
  const b = text.indexOf(end, a + 1);
  if (a < 0 || b < 0 || text.indexOf(start, a + 1) >= 0) fail(`${where}: markers ${JSON.stringify(start.slice(0, 60))} .. ${JSON.stringify(end.slice(0, 60))} not found exactly once`);
  return text.slice(0, a) + to + text.slice(b);
}

// --- the defined text transform (D-3) --------------------------------------
const NAMES = [...ROSTER, ...OTHER_SKILLS].sort((x, y) => y.length - x.length).join('|');
const SLASH_AT = new RegExp('^/(' + NAMES + ')(?![\\w-])');
const SLASH = new RegExp('(?<![\\w./$-])/(' + NAMES + ')(?![\\w-])', 'g');

// A `/command` mention in a shell script becomes `$command`. In double quotes or
// unquoted it would expand as a variable, so there it is written `\$command`; in
// single quotes and in comments the plain `$command` is literal.
function slashInShell(line) {
  if (/^\s*#/.test(line)) return line.replace(SLASH, '$$$1');
  let out = '', quote = '', i = 0;
  while (i < line.length) {
    const c = line[i];
    if (quote === "'") {
      const m = c === '/' ? line.slice(i).match(SLASH_AT) : null;
      if (m && !/[\w./$-]/.test(line[i - 1] ?? '')) { out += '$' + m[1]; i += m[0].length; continue; }
      if (c === "'") quote = '';
      out += c; i++; continue;
    }
    if (c === '\\') { out += c + (line[i + 1] ?? ''); i += 2; continue; }
    if (c === '"') { quote = quote === '"' ? '' : '"'; out += c; i++; continue; }
    if (c === "'" && quote === '') { quote = "'"; out += c; i++; continue; }
    const m = c === '/' ? line.slice(i).match(SLASH_AT) : null;
    if (m && !/[\w./$-]/.test(line[i - 1] ?? '')) { out += '\\$' + m[1]; i += m[0].length; continue; }
    out += c; i++;
  }
  return out;
}

function toCodex(text, kind = 'md') {
  text = text.replaceAll('${CLAUDE_CONFIG_DIR:-$HOME/.claude}', AGENTS_DIR);
  text = text.replace(/(atlas-check\.sh"?|doctor\.sh"?) claude\b/g, '$1 codex');
  text = text.replaceAll('.claude/docs/diagrams', 'docs/diagrams');
  text = text.replaceAll('claude-bootstrap', 'codex-bootstrap');
  // Backticks would be command substitution inside the double-quoted strings of a script.
  const dir = kind === 'sh' ? '(~/.agents)' : '(`~/.agents`)';
  text = text.replace(/the Claude config(\s+)directory/g, `the agents$1directory ${dir}`)
    .replace(/Claude config(\s+)directory/g, `agents$1directory ${dir}`)
    .replaceAll('Claude Code', 'Codex');
  if (kind === 'sh') return text.split('\n').map(slashInShell).join('\n');
  return text.replace(SLASH, '$$$1');
}

function frontmatter(text, where) {
  const match = text.match(/^---\n([\s\S]*?)\n---\n/);
  if (!match) fail(`${where}: no frontmatter`);
  return match;
}
// SKILL.md frontmatter keeps only name and description (D-2); the user-only
// switch moves to agents/openai.yaml.
function slimFrontmatter(text, where) {
  const match = frontmatter(text, where);
  const keep = [];
  let key = null;
  for (const line of match[1].split('\n')) {
    const top = line.match(/^([A-Za-z][\w-]*):/);
    if (top) key = top[1];
    if (key === 'name' || key === 'description') keep.push(line);
  }
  if (keep.length < 2) fail(`${where}: name and description required`);
  return `---\n${keep.join('\n')}\n---\n` + text.slice(match[0].length);
}

function descriptionOf(text, where) {
  const line = frontmatter(text, where)[1].split('\n').find(l => l.startsWith('description:'));
  return line.slice('description:'.length).trim().replace(/^"|"$/g, '').replace(/\\"/g, '"');
}
function titleOf(name) {
  return name.split('-').map(w => w === 'rea' ? 'REA' : w[0].toUpperCase() + w.slice(1)).join(' ');
}
function shortOf(description) {
  let sentence = description.split(/(?<=[a-z)])\.\s|: [/$]/)[0].replace(/\s+/g, ' ').trim().replace(/[.:]$/, '');
  if (sentence.length > 110) sentence = sentence.slice(0, 110).replace(/\s+\S*$/, '') + '…';
  return sentence.replaceAll('\\', '').replaceAll('"', "'");
}
// Picker text for the skills this converter knows; a Command it has not seen
// (T048's three, until they merge) falls back to the description's first clause.
const SHORT = {
  'map-repo': "Build or update the repository's knowledge graph",
  'map-ask': "Answer a question from the repository's graph",
  'map-impact': 'Report what a change touches, from the graph',
  diagram: 'Draw a diagram from a description',
  'diagram-repo': "Draw the repository's architecture from its graph",
  'diagram-flow': 'Trace one flow through the graph and draw it',
  'atlas-doctor': "Check the atlas pack's setup (read-only)",
  'rea-doctor': 'Diagnose the REA setup',
  'rea-triage': 'Identify a target and propose the REA workflow',
  'rea-feature': 'Explain how one feature of a binary works',
  'rea-diagram': "Draw one feature of a binary from REA's evidence",
  'rea-map': 'Build a knowledge graph of decompiled code (experimental)',
  'rea-update': 'Update REA to its latest release',
  archify: 'Architecture and workflow diagrams as standalone HTML',
  graphify: 'Knowledge graph of a codebase or corpus',
};
function openaiYaml(name, skill) {
  const short = SHORT[name] ?? shortOf(descriptionOf(skill, name));
  return `interface:\n  display_name: "${titleOf(name)}"\n  short_description: "${short}"\npolicy:\n  allow_implicit_invocation: false\n`;
}

// --- Codex-specific seams in the pack-authored files -------------------------
// Each replacement runs on the Claude text, before the shared transform, and must
// match exactly the stated number of times: a change in the Claude source that
// moves a seam fails here instead of drifting silently.
const snippet = name => fs.readFileSync(path.join(import.meta.dirname, 'atlas-codex', name), 'utf8');
const DOCTOR_CONFIG_AND_MIGRATION = snippet('doctor-config-and-migration.sh');
const DOCTOR_HOOK_TRACES = snippet('doctor-hook-traces.sh');
const REA_ENV_SERVER = snippet('rea-env-server.sh');

// The ATLAS-REA-ENV block finds REA's MCP server as a child of CLAUDE_PID. A Codex
// session has no such process id (an inherited one would name another agent's
// server), so the mirror reads the server from Codex's configuration instead
// (tools/atlas-codex/rea-env-server.sh) and keeps the environment checks that follow.
function reaServerDiscovery(text, where) {
  text = between(text, '# _rea_ppid <pid>:', '    case "$_REER" in\n        *"$_REENL"*)', REA_ENV_SERVER, where);
  text = exactly(text, '(process $_REEM) was removed', '(from its config entry) was removed', where);
  return between(text, '#   _rea_env_server  the environment of the one "rea mcp" child of the', '# _rea_env_scan then checks', `#   _rea_env_server  the environment of REA's MCP server as Codex's
#                    configuration starts it (the [mcp_servers.rea] entry
#                    of the closest .codex/config.toml, else CODEX_HOME's;
#                    no process id is read), in _REE, its working directory
#                    in _REECWD, and the area around that directory, by
#                    its physical name and by the snapshot's PWD when
#                    that names it, in _REESP and _REESL. It prints why
#                    and returns 1
#                    when it cannot be read with certainty: no entry, an
#                    entry this reader can't parse or that does not run
#                    "rea mcp", a relative CODEX_HOME, a cwd that can't be
#                    entered, a value holding a line break.
`, where);
}

const ADAPT = {
  'atlas-doctor/scripts/atlas-archify.sh': (text, where) =>
    exactly(text, 'the Claude config directory, $_ABV, is not an absolute path; set CLAUDE_CONFIG_DIR to one.',
      'the agents directory, $_ABV, is not an absolute path; set HOME to an absolute path.', where),
  'atlas-doctor/scripts/atlas-check.sh': (text, where) => {
    text = reaServerDiscovery(text, where);
    text = exactly(text, '# <client> selects the config dir: claude is $CLAUDE_CONFIG_DIR, else\n# ~/.claude. The Codex mirror carries its own copy for codex (FR-047).',
      '# <client> selects the config dir: codex is ~/.agents. This copy takes no other\n# client; the Claude kit carries its own for claude (FR-047).', where);
    text = exactly(text, '"${ATLAS_CLIENT:-claude}"', '"${ATLAS_CLIENT:-codex}"', where);
    // A relative HOME would resolve the runner against the repository (the untrusted area).
    return exactly(text, 'claude) ATLAS_CLIENT=claude; ATLAS_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ;;',
      'codex)\n            ATLAS_CLIENT=codex\n            ATLAS_CONFIG_DIR="$HOME/.agents"\n            case "$ATLAS_CONFIG_DIR" in\n                /*) ;;\n                *) printf \'%s\\n\' "atlas-check.sh: HOME is not an absolute path; set HOME to one." >&2; return 2 ;;\n            esac\n            ;;', where);
  },
  'rea-android/scripts/tool-check.sh': (text, where) => {
    text = reaServerDiscovery(text, where);
    text = exactly(text, `# environment from /proc/<pid>/environ of the one process whose parent is
# the agent (CLAUDE_PID, which must be an ancestor of this script) and
# whose command line is "rea mcp", and applies FR-038's environment rule to
# it`, `# environment from Codex's configuration of REA's MCP server (the
# [mcp_servers.rea] entry of the closest .codex/config.toml, else CODEX_HOME's;
# no process id is read) and applies FR-038's environment rule to
# it`, where);
    return exactly(text, `# same way when the environment can't be read with certainty: no /proc,
# CLAUDE_PID not an ancestor, no such server or more than one, an
# unreadable environment, a value holding a line break, or a name set twice.`,
      `# same way when the environment can't be read with certainty: no rea entry
# in Codex's config.toml, an entry that can't be read or does not run "rea
# mcp", a relative CODEX_HOME, a cwd that can't be entered, or a name set twice.`, where);
  },
  'rea-binary/scripts/provider-check.sh': (text, where) => {
    text = reaServerDiscovery(text, where);
    return exactly(text, `# read from /proc/<pid>/environ of the one "rea mcp" child of the agent
# (CLAUDE_PID, an ancestor of this script); when it can't be read with
# certainty the helper stops and says why.`, `# read from Codex's configuration of REA's MCP server (the [mcp_servers.rea]
# entry of the closest .codex/config.toml, else CODEX_HOME's); when it can't be
# read with certainty the helper stops and says why.`, where);
  },
  'atlas-doctor/scripts/doctor.sh': (text, where) => {
    text = exactly(text, `#   rea-mcp         rea doctor --client claude_code (REA's name for Claude
#                   Code's registration, mapped by the shared script's
#                   atlas_rea_client, which the REA Commands use too, and
#                   printed by its report, so the doctor and /rea-doctor
#                   print the same lines); rea-skill: rea doctor --skill
#                   --client claude_code, Claude Code's own skill copy
#                   under the config dir (without --client, REA checks the
#                   shared ~/.agents/skills copy instead);
#                   rea-doctor: a plain rea doctor (healthy and its scope
#                   checks), its output shown when it is not healthy;
#   migration-*     FR-042: <config-dir>/skills/archify a symlink; a
#                   .graphify_version stamp in <config-dir>/skills/graphify/
#                   or ~/.agents/skills/graphify/; a "# graphify" section in
#                   <config-dir>/CLAUDE.md;
`, `#   rea-mcp         rea doctor --client codex (REA's name for Codex's
#                   registration, mapped by the shared script's
#                   atlas_rea_client, which the REA Commands use too, and
#                   printed by its report, so the doctor and /rea-doctor
#                   print the same lines); rea-skill: rea doctor --skill
#                   --client codex, Codex's skill copy;
#                   rea-doctor: a plain rea doctor (healthy and its scope
#                   checks), its output shown when it is not healthy;
#   multi_agent     decision brief D-5: config.toml in CODEX_HOME (default
#                   ~/.codex) sets [features] multi_agent = true, which
#                   Graphify's parallel semantic extraction needs; a [warn]
#                   with the two lines to add, and the file is never edited;
#   rea-config      D-6: the same file has an [mcp_servers.rea] entry;
#   migration-*     D-4: <agents-dir>/skills/archify a symlink; a
#                   .graphify_version stamp in <agents-dir>/skills/graphify/;
#                   an archify or graphify skill directory the atlas pack's
#                   install record doesn't list (an identical copy the
#                   installer never adopted), with the line that moves it out
#                   of the skills directory;
`, where);
    text = exactly(text, '#                   settings.local.json; a graphify block in post-commit or',
      '#                   settings.local.json (trace-pretooluse), or in\n#                   .codex/hooks.json (trace-codex-hooks); a graphify block in post-commit or', where);
    text = exactly(text, '# The largest .claude/settings*.json the PreToolUse scan reads (bytes).',
      '# The largest hook settings file the PreToolUse scan reads (bytes).', where);
    text = between(text, '# --- Migration (FR-042)', '# --- Traces (FR-043)', DOCTOR_CONFIG_AND_MIGRATION, where);
    text = exactly(text, '_doctor_traces() {\n    local f found hooks name st', DOCTOR_HOOK_TRACES + '_doctor_traces() {\n    local f found hooks name st', where);
    text = between(text, '    for f in settings.json settings.local.json; do', '\n    if [ -z "$_DOCTOR_GIT" ]; then',
      '    _doctor_hook_traces trace-pretooluse "claude uninstall --project" "${_DOCTOR_TOP}/.claude/settings.json" "${_DOCTOR_TOP}/.claude/settings.local.json"\n    _doctor_hook_traces trace-codex-hooks "codex uninstall" "${_DOCTOR_TOP}/.codex/hooks.json"\n', where);
    text = exactly(text, `    if [ "$#" -ne 1 ] || [ "$1" != claude ]; then
        printf 'usage: doctor.sh claude\\n' >&2
        return 2
    fi
    ATLAS_CLIENT=claude
    ATLAS_REA_ENV_WARN=1
    ATLAS_CONFIG_DIR="\${CLAUDE_CONFIG_DIR:-$HOME/.claude}"`, `    if [ "$#" -ne 1 ] || [ "$1" != codex ]; then
        printf 'usage: doctor.sh codex\\n' >&2
        return 2
    fi
    ATLAS_CLIENT=codex
    ATLAS_REA_ENV_WARN=1
    ATLAS_CONFIG_DIR="$HOME/.agents"
    case "$ATLAS_CONFIG_DIR" in
        /*) ;;
        *) printf 'doctor.sh: HOME is not an absolute path; set HOME to one.\\n' >&2; return 2 ;;
    esac`, where);
    return exactly(text, '    _doctor_rea\n    _doctor_migration\n', '    _doctor_rea\n    _doctor_codex_config\n    _doctor_migration\n', where);
  },
  'rea-android/SKILL.md': (text, where) =>
    exactly(text, 'It reads only files and `/proc`, and\nruns no tool.', 'It reads only files (Codex\'s `config.toml`), and\nruns no tool.', where),
  'atlas-doctor/SKILL.md': (text, where) => {
    text = exactly(text, "REA's registration for this client, the one-time migration steps,",
      "REA's registration for this client, Codex's `multi_agent` setting and REA's `config.toml` entry, the one-time migration steps,", where);
    text = exactly(text, `- **Migration** (\`migration-*\`; the pack notes, "Migration"): the
  pre-pack installs of both skills in the config directory and in
  \`~/.agents/skills\`.
`, `- **Codex config** (\`multi_agent\`, \`rea-config\`): whether \`config.toml\` in
  \`CODEX_HOME\` (default \`~/.codex\`) sets \`[features] multi_agent = true\`,
  which Graphify's parallel semantic extraction needs, and has an
  \`[mcp_servers.rea]\` entry. A \`[warn]\` is followed by the lines to add; the
  doctor never edits the file.
- **Migration** (\`migration-*\`; the pack notes, "Migration"): an Archify or
  Graphify skill directory in \`~/.agents/skills\` that the atlas pack's
  install record doesn't list, with the line that moves it out, and a
  \`.graphify_version\` file in Graphify's directory.
`, where);
    return text;
  },
  'diagram/scripts/keep-copy.sh': (text, where) => {
    text = exactly(text, '# must be a real directory and a real file, and .claude, .claude/docs,\n# .claude/docs/diagrams and the copy must each be absent or real.',
      '# must be a real directory and a real file, and docs, docs/diagrams and\n# the copy must each be absent or real.', where);
    return exactly(text, 'for p in .claude .claude/docs "$dest_dir"; do', 'for p in docs "$dest_dir"; do', where);
  },
};

function convertCommandFile(rel, text) {
  const adapt = ADAPT[rel];
  let out = adapt ? adapt(text, rel) : text;
  out = toCodex(out, rel.endsWith('.sh') ? 'sh' : 'md');
  if (rel.endsWith('/SKILL.md')) out = slimFrontmatter(out, rel);
  return out;
}

// --- the vendored skills -----------------------------------------------------
const delta = JSON.parse(fs.readFileSync(path.join(import.meta.dirname, 'atlas-graphify-agents-delta.json'), 'utf8'));
function graphifySkill(text) {
  const where = 'graphify/SKILL.md';
  // Part B of the Claude kit's skill tells the session to dispatch with the Agent
  // tool (subagent_type, usage counts), which Codex lacks. The delta file holds
  // the Codex adaptation: chunk list files, native subagents (spawn_agent,
  // wait_agent, close_agent) when multi_agent is on, a serial path when it is
  // off, and a collection check. It supersedes upstream's skill-agents.md Part B
  // wording, which names a Task tool Codex does not have either. Each replacement
  // must match once, so a change in the Claude source stops the converter. The
  // pin is the same: b4e6307.
  for (const r of delta.replacements) text = exactly(text, r.from, r.to, `${where}: ${r.label}`);
  text = exactly(text, 'confidence rubric, frontmatter, hyperedge', 'confidence rubric, hyperedge', where);
  text = toCodex(text);
  if (text.split('Modified by the codex-bootstrap atlas pack').length !== 2) fail(`${where}: modification notice`);
  return slimFrontmatter(text, where);
}

// --- walk and write -----------------------------------------------------------
function walk(dir) {
  return fs.readdirSync(dir, {withFileTypes: true}).flatMap(e => {
    const p = path.join(dir, e.name);
    if (e.isSymbolicLink()) fail(`source symlink: ${p}`);
    return e.isDirectory() ? walk(p) : [p];
  }).sort();
}
const sha = buf => crypto.createHash('sha256').update(buf).digest('hex');

// Nothing under the pack is touched until the whole replacement exists: the roster
// check, every transform and every seam run into a staging directory beside the
// output, which is then swapped in. On any failure the previous skills tree and
// source map stay byte-identical and the staging directory is removed.
const present = fs.readdirSync(sourceSkills).sort();
const unknown = present.filter(n => !ROSTER.includes(n) && !VENDORED.includes(n));
if (unknown.length) fail(`unknown skill(s) in the source pack: ${unknown.join(', ')}`);
// docs/ holds the map for the real pack: assets/ may not name the Claude source paths it records.
const mapFile = outFlag >= 0 ? path.join(outDir, 'source-map.json') : path.join(root, 'docs/atlas-source-map.json');
const notYet = ROSTER.filter(n => !present.includes(n));
const SKILLS_REL = 'global/.agents/skills';
const skillsDir = path.join(outDir, SKILLS_REL);
fs.mkdirSync(path.dirname(skillsDir), {recursive: true});
fs.mkdirSync(path.dirname(mapFile), {recursive: true});
const stage = fs.mkdtempSync(path.join(path.dirname(skillsDir), '.skills-stage-'));
fs.chmodSync(stage, 0o755);
const stageMap = path.join(path.dirname(mapFile), `.${path.basename(mapFile)}.stage-${path.basename(stage)}`);
const files = [];
const emitted = new Map();
function emit(rel, content, mode, source, transform) {
  const dest = path.join(SKILLS_REL, rel);
  const full = path.join(stage, rel);
  fs.mkdirSync(path.dirname(full), {recursive: true});
  fs.writeFileSync(full, content, {mode});
  emitted.set(rel, content);
  files.push({source: path.relative(sourceKit, source), source_sha256: sha(fs.readFileSync(source)),
    destination: dest, destination_sha256: sha(Buffer.from(content)), transform});
}

// The runner's ATLAS-BOUNDARY block, whole (marker lines included), as the converter emitted it.
function boundaryBlock() {
  const runner = String(emitted.get('graphify/atlas-graphify.sh') ?? fail('graphify/atlas-graphify.sh is not in the source pack'));
  const begin = runner.indexOf('# ATLAS-BOUNDARY-BEGIN\n');
  const endMark = '# ATLAS-BOUNDARY-END\n';
  const end = runner.indexOf(endMark);
  if (begin < 0 || end < begin || runner.indexOf('# ATLAS-BOUNDARY-BEGIN\n', begin + 1) >= 0) fail('atlas-graphify.sh: ATLAS-BOUNDARY markers not found exactly once');
  return runner.slice(begin, end + endMark.length);
}

function build() {
  for (const file of walk(sourceSkills)) {
    const rel = path.relative(sourceSkills, file);
    const skill = rel.split(path.sep)[0];
    const mode = fs.statSync(file).mode & 0o777;
    const bytes = fs.readFileSync(file);
    const text = () => bytes.toString('utf8');
    if (skill === 'archify') {
      // Byte copies of the Claude pack's vendored tree (same pin, same patches),
      // except SKILL.md: the wrapper sentence's path and the slim frontmatter.
      if (rel === 'archify/SKILL.md') emit(rel, slimFrontmatter(toCodex(text()), rel), mode, file, 'archify-skill');
      else emit(rel, bytes, mode, file, 'copy');
    } else if (skill === 'graphify') {
      const base = path.basename(rel);
      if (rel === 'graphify/SKILL.md') emit(rel, graphifySkill(text()), mode, file, 'graphify-skill');
      else if (['LICENSE', 'NOTICE', 'LICENSE-MIT'].includes(base)) emit(rel, bytes, mode, file, 'copy');
      else if (rel.startsWith('graphify/references/')) emit(rel, toCodex(text()), mode, file, 'reference');
      else emit(rel, convertCommandFile(rel, text()), mode, file, 'script');
    } else if (/\.(md|sh|txt)$/.test(rel)) {
      emit(rel, convertCommandFile(rel, text()), mode, file, rel.endsWith('/SKILL.md') ? 'command' : 'script');
    } else {
      fail(`unexpected file in a Command: ${rel}`);
    }
  }
  // The Graphify chunk reader exists only here: a Claude worker has a file-reading
  // tool, a standard Codex session has none. It is native to this kit, not derived
  // from the Claude pack, so its record names this repository's file as the source.
  // Its shell entry point carries the runner's ATLAS-BOUNDARY block, spliced in whole.
  for (const [name, mode] of [['atlas-read-chunk.py', 0o755], ['atlas-read-chunk.sh', 0o755]]) {
    const native = path.join(import.meta.dirname, 'atlas-codex', name);
    let bytes = fs.readFileSync(native);
    const placeholder = '# @@ATLAS-BOUNDARY@@\n';
    if (name.endsWith('.sh')) {
      const template = bytes.toString('utf8');
      if (template.split(placeholder).length !== 2) fail(`${name}: boundary placeholder not found exactly once`);
      bytes = Buffer.from(template.replace(placeholder, () => boundaryBlock()));
    }
    const dest = path.join(SKILLS_REL, 'graphify', name);
    fs.writeFileSync(path.join(stage, 'graphify', name), bytes, {mode});
    files.push({source: path.relative(root, native), source_sha256: sha(fs.readFileSync(native)), destination: dest,
      destination_sha256: sha(bytes), transform: 'kit-native'});
  }
  for (const name of [...ROSTER.filter(n => present.includes(n)), ...VENDORED]) {
    const skill = fs.readFileSync(path.join(stage, name, 'SKILL.md'), 'utf8');
    const yamlPath = path.join(stage, name, 'agents/openai.yaml');
    fs.mkdirSync(path.dirname(yamlPath), {recursive: true});
    fs.writeFileSync(yamlPath, openaiYaml(name, skill));
  }
  let commit = 'unknown';
  try { commit = execFileSync('git', ['-C', sourceKit, 'rev-parse', 'HEAD'], {encoding: 'utf8'}).trim(); } catch { /* not a git checkout */ }
  fs.writeFileSync(stageMap, JSON.stringify({
    converter: 'tools/migrate-atlas.mjs', source_kit: 'claude-bootstrap-protocol', source_commit: commit,
    commands_not_yet_derived: notYet, files}, null, 2) + '\n');
  return commit;
}

function swapIn() {
  const old = `${stage}.old`;
  const hadSkills = fs.existsSync(skillsDir);
  if (hadSkills) fs.renameSync(skillsDir, old);
  try {
    fs.renameSync(stage, skillsDir);
    fs.renameSync(stageMap, mapFile);
  } catch (error) {
    // Put the previous tree back; the map is renamed last, so it is still the previous one.
    fs.rmSync(skillsDir, {recursive: true, force: true});
    if (hadSkills) fs.renameSync(old, skillsDir);
    throw error;
  }
  fs.rmSync(old, {recursive: true, force: true});
}

let commit;
try {
  commit = build();
  swapIn();
} finally {
  fs.rmSync(stage, {recursive: true, force: true});
  fs.rmSync(stageMap, {force: true});
}
console.log(`Derived ${files.length} atlas files from ${commit.slice(0, 7)}; not yet in the source: ${notYet.join(', ') || 'none'}.`);
