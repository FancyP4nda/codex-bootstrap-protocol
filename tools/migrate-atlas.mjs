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
    if (quote === "'") { if (c === "'") quote = ''; out += c; i++; continue; }
    if (c === '\\') { out += c + (line[i + 1] ?? ''); i += 2; continue; }
    if (c === '"') { quote = quote === '"' ? '' : '"'; out += c; i++; continue; }
    if (c === "'") { quote = "'"; out += c; i++; continue; }
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
  text = text.replace(/the Claude config(\s+)directory/g, 'the agents$1directory (`~/.agents`)')
    .replace(/Claude config(\s+)directory/g, 'agents$1directory (`~/.agents`)')
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

const ADAPT = {
  'atlas-doctor/scripts/atlas-archify.sh': (text, where) =>
    exactly(text, 'the Claude config directory, $_ABV, is not an absolute path; set CLAUDE_CONFIG_DIR to one.',
      'the agents directory, $_ABV, is not an absolute path; set HOME to an absolute path.', where),
  'atlas-doctor/scripts/atlas-check.sh': (text, where) => {
    text = exactly(text, '# <client> selects the config dir: claude is $CLAUDE_CONFIG_DIR, else\n# ~/.claude. The Codex mirror carries its own copy for codex (FR-047).',
      '# <client> selects the config dir: codex is ~/.agents. This copy takes no other\n# client; the Claude kit carries its own for claude (FR-047).', where);
    text = exactly(text, '"${ATLAS_CLIENT:-claude}"', '"${ATLAS_CLIENT:-codex}"', where);
    return exactly(text, 'claude) ATLAS_CLIENT=claude; ATLAS_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ;;',
      'codex) ATLAS_CLIENT=codex; ATLAS_CONFIG_DIR="$HOME/.agents" ;;', where);
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
    text = between(text, '_doctor_migration() {', '# --- Traces (FR-043)', DOCTOR_CONFIG_AND_MIGRATION, where);
    text = exactly(text, '_doctor_traces() {\n    local f found hooks name st', DOCTOR_HOOK_TRACES + '_doctor_traces() {\n    local f found hooks name st', where);
    text = between(text, '    for f in settings.json settings.local.json; do', '\n    if [ -z "$_DOCTOR_GIT" ]; then',
      '    _doctor_hook_traces trace-pretooluse "claude uninstall --project" "${_DOCTOR_TOP}/.claude/settings.json" "${_DOCTOR_TOP}/.claude/settings.local.json"\n    _doctor_hook_traces trace-codex-hooks "codex uninstall" "${_DOCTOR_TOP}/.codex/hooks.json"\n', where);
    text = exactly(text, `    if [ "$#" -ne 1 ] || [ "$1" != claude ]; then
        printf 'usage: doctor.sh claude\\n' >&2
        return 2
    fi
    ATLAS_CLIENT=claude
    ATLAS_CONFIG_DIR="\${CLAUDE_CONFIG_DIR:-$HOME/.claude}"`, `    if [ "$#" -ne 1 ] || [ "$1" != codex ]; then
        printf 'usage: doctor.sh codex\\n' >&2
        return 2
    fi
    ATLAS_CLIENT=codex
    ATLAS_CONFIG_DIR="$HOME/.agents"`, where);
    return exactly(text, '    _doctor_rea\n    _doctor_migration\n', '    _doctor_rea\n    _doctor_codex_config\n    _doctor_migration\n', where);
  },
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
  // Upstream's skill-agents.md (the agents-root variant) differs from skill.md,
  // which the Claude kit vendors, in the subagent dispatch block and one list in
  // Step B2's pointer; the closing hook pointers differ too, but the Claude
  // patch replaces those. The pin is the same: b4e6307.
  text = exactly(text, delta.from, delta.to, where);
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
const files = [];
function emit(rel, content, mode, source, transform) {
  const dest = path.join('global/.agents/skills', rel);
  const full = path.join(outDir, dest);
  fs.mkdirSync(path.dirname(full), {recursive: true});
  fs.writeFileSync(full, content, {mode});
  files.push({source: path.relative(sourceKit, source), source_sha256: sha(fs.readFileSync(source)),
    destination: dest, destination_sha256: sha(Buffer.from(content)), transform});
}

fs.rmSync(path.join(outDir, 'global/.agents/skills'), {recursive: true, force: true});
const present = fs.readdirSync(sourceSkills).sort();
const unknown = present.filter(n => !ROSTER.includes(n) && !VENDORED.includes(n));
if (unknown.length) fail(`unknown skill(s) in the source pack: ${unknown.join(', ')}`);
// docs/ holds the map for the real pack: assets/ may not name the Claude source paths it records.
const mapFile = outFlag >= 0 ? path.join(outDir, 'source-map.json') : path.join(root, 'docs/atlas-source-map.json');
const notYet = ROSTER.filter(n => !present.includes(n));

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
for (const name of [...ROSTER.filter(n => present.includes(n)), ...VENDORED]) {
  const skill = fs.readFileSync(path.join(outDir, 'global/.agents/skills', name, 'SKILL.md'), 'utf8');
  const yamlPath = path.join(outDir, 'global/.agents/skills', name, 'agents/openai.yaml');
  fs.mkdirSync(path.dirname(yamlPath), {recursive: true});
  fs.writeFileSync(yamlPath, openaiYaml(name, skill));
}

let commit = 'unknown';
try { commit = execFileSync('git', ['-C', sourceKit, 'rev-parse', 'HEAD'], {encoding: 'utf8'}).trim(); } catch { /* not a git checkout */ }
fs.writeFileSync(mapFile, JSON.stringify({
  converter: 'tools/migrate-atlas.mjs', source_kit: 'claude-bootstrap-protocol', source_commit: commit,
  commands_not_yet_derived: notYet, files}, null, 2) + '\n');
console.log(`Derived ${files.length} atlas files from ${commit.slice(0, 7)}; not yet in the source: ${notYet.join(', ') || 'none'}.`);
