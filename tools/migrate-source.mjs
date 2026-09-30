#!/usr/bin/env node
// Mechanical, allowlisted migration. Run only against this builder repository.
// Semantic native replacements are maintained separately, never in this importer.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
const root = path.resolve(import.meta.dirname, '..');
const source = path.resolve(process.argv[2] || path.join(root, '../claude-bootstrap-protocol'));
const inventory = [];
const map = p => p.replaceAll('.claude/skills', '.agents/skills')
  .replaceAll('.claude/agents/navigator/', '.codex/agents/')
  .replaceAll('.claude/agents/herald/', '.codex/agents/')
  .replaceAll('.claude/docs', 'docs').replaceAll('.claude/templates', '.agents/templates')
  .replaceAll('.claude/rules', '.agents/bootstrap/instructions')
  .replaceAll('.claude/tmp', '.codex/state/tmp').replaceAll('.claude/CLAUDE.md', 'AGENTS.md');
function convert(text, rel) {
  // Code identifiers must not be provider-renamed mechanically (runClaude and
  // runCodex, for example, are distinct functions). Native adapters are reviewed
  // separately after this path-only conversion.
  if (/\.(mjs|js)$/.test(rel)) return map(text);
  text = map(text).replaceAll('~/.claude/', '~/.agents/bootstrap/')
    .replaceAll('claude-bootstrap', 'codex-bootstrap')
    .replaceAll('CLAUDE_SESSION_ID', 'CODEX_SESSION_ID').replaceAll('CLAUDE.md', 'AGENTS.md')
    .replaceAll('Claude Code', 'Codex').replaceAll('Claude', 'Codex')
    .replaceAll('AskUserQuestion', 'request_user_input_async (or a concise question)')
    .replaceAll('TaskCreate', 'bd create').replaceAll('TaskUpdate', 'bd update')
    .replaceAll('TodoWrite', 'bd create').replaceAll('WebSearch', 'available web search')
    .replaceAll('WebFetch', 'available page retrieval')
    .replace(/\bAgent tool\b/g, 'spawn_agent tool').replace(/\bsubagent_type:/g, 'agent_type:');
  text = text.replace(/^allowed-tools:.*\n/gm, '').replace(/^model:.*\n/gm, '')
    .replace(/^disable-model-invocation:.*\n/gm, '');
  // Commands become native skill invocation; URLs and filesystem paths stay intact.
  for (const name of ['session-start','session-wrapup','session-checkpoint','falcon','herald','brainstormer','grill-with-docs','product-architect','project-planner','plan-to-beads-unified','refine-beads','tdd','wizard','wait-what','to-questionnaire']) {
    text = text.replace(new RegExp('(?<![\\w.:/])/('+name+')\\b','g'), '$$$1');
  }
  if (rel.endsWith('SKILL.md')) {
    const match = text.match(/^---\n([\s\S]*?)\n---\n/);
    if (match) {
      const name = match[1].match(/^name:\s*(.*)$/m)?.[1];
      const description = match[1].match(/^description:\s*(.*)$/m)?.[1];
      if (name && description) text = `---\nname: ${name}\ndescription: ${description}\n---\n` + text.slice(match[0].length);
    }
  }
  return text;
}
function walk(dir) {
  return fs.readdirSync(dir, {withFileTypes:true}).flatMap(e => {
    if (e.name === '__pycache__' || e.name === '.gitkeep') return [];
    const p = path.join(dir,e.name);
    if (e.isSymbolicLink()) throw Error(`source symlink: ${p}`);
    return e.isDirectory() ? walk(p) : [p];
  });
}
function add(from, dest) {
  const input = fs.readFileSync(from);
  let text = convert(input.toString('utf8'), dest);
  if (from.includes('/agents/') && from.endsWith('.md')) {
    const name = path.basename(from,'.md');
    const description = text.match(/^description:\s*(.+)$/m)?.[1] || `${name} specialist`;
    const body = text.replace(/^---\n[\s\S]*?\n---\n/, '');
    const mode = /recon|survey|review|a11y|maintenance/.test(name) ? 'read-only' : 'workspace-write';
    text = `name = ${JSON.stringify(name)}\ndescription = ${JSON.stringify(description)}\nsandbox_mode = "${mode}"\ndeveloper_instructions = ${JSON.stringify(body)}\n`;
    dest = dest.replace(/\.md$/, '.toml');
  }
  const full = path.join(root,dest);
  fs.mkdirSync(path.dirname(full), {recursive:true});
  fs.writeFileSync(full,text,{mode:fs.statSync(from).mode & 0o777});
  inventory.push({source:path.relative(source,from), destination:dest,
    source_sha256:crypto.createHash('sha256').update(input).digest('hex'),
    acceptance:dest.endsWith('.toml')?'native-agent-schema':dest.includes('/skills/')?'skill-discovery-and-supporting-assets':'manifest-and-runtime-scan'});
}
if (process.argv[3] === '--code-only') {
  for (const file of walk(path.join(source,'assets/packs/web-design'))) {
    if (/\.(mjs|js)$/.test(file)) add(file,'assets/packs/web-design/'+map(path.relative(path.join(source,'assets/packs/web-design'),file)));
  }
  console.log('Refreshed path-only web-design code; native adaptations must follow.');
  process.exit(0);
}
for (const file of walk(path.join(source,'assets/global/.claude'))) {
  let rel = path.relative(path.join(source,'assets/global'),file);
  if (rel.startsWith('.claude/rules/')) rel = rel.replace('.claude/rules/', '.agents/bootstrap/instructions/');
  add(file,'assets/global/'+map(rel));
}
for (const file of walk(path.join(source,'assets/scaffold'))) {
  const rel=path.relative(path.join(source,'assets/scaffold'),file);
  if (/settings\.json|statusline|hooks\/|prompts\//.test(rel)) {
    inventory.push({source:'assets/scaffold/'+rel,destination:'native-hooks-and-tui',acceptance:'native-config-and-hook-payload'});
  } else add(file,'assets/scaffold/'+map(rel));
}
for (const file of walk(path.join(source,'assets/packs'))) add(file,'assets/packs/'+map(path.relative(path.join(source,'assets/packs'),file)));
for (const file of walk(path.join(source,'verification/pack-validator'))) add(file,'verification/pack-validator/'+path.basename(file));
for (const file of walk(path.join(source,'verification/fixtures'))) add(file,'verification/fixtures/'+map(path.relative(path.join(source,'verification/fixtures'),file)));
add(path.join(source,'lib/plan-engine.sh'),'lib/plan-engine.sh');
inventory.push({source:'bootstrap',destination:'bootstrap',acceptance:'installer-regression-suite',conversion:'selective engine reuse; native global config and wizard replace source runtime'});
const commit=execFileSync('git',['-C',source,'rev-parse','HEAD'],{encoding:'utf8'}).trim();
fs.writeFileSync(path.join(root,'docs/source-inventory.json'),JSON.stringify({source_commit:commit,assets:inventory},null,2)+'\n');
console.log(`Converted ${inventory.length} inventoried assets from ${commit}`);
