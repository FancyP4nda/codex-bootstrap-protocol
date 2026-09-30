#!/usr/bin/env node
// Mechanical text cleanup after the reviewed native code adaptations.
import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'..');
const web=path.join(root,'assets/packs/web-design/scaffold/.agents/skills/impeccable');
function walk(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(path.join(dir,e.name)):[path.join(dir,e.name)]);}
for(const file of walk(web)) {
  if(path.basename(file)==='LICENSE') continue;
  let text=fs.readFileSync(file,'utf8');
  const old=text;
  // Repair earlier mechanical path substitutions, then convert command tokens only.
  if(/\.(js|mjs)$/.test(file)) text=text.replaceAll('$impeccable','/impeccable');
  else text=text.replace(/([\w.:/])\$impeccable/g,'$1/impeccable')
    .replace(/(?<![\w.:/])\/impeccable\b/g,'$$impeccable');
  text=text.replaceAll('Codex, Codex','Codex')
    .replaceAll('Codex and Codex','Codex').replaceAll('auto|codex|claude|mock','auto|codex|mock');
  if(file.endsWith('context.mjs')&&!text.includes('defaults to no vendor update ping')) text=text.replace(/(import \{ IMPECCABLE_COMMAND, IMPECCABLE_PROVIDER_ID \} from '\.\/lib\/provider\.mjs';)/,'$1\n// This native migration defaults to no vendor update ping.\nprocess.env.IMPECCABLE_NO_UPDATE_CHECK ??= "1";');
  if(file.endsWith('concept-seed.mjs')&&!text.includes('Explicit opt-in is required for upstream choice telemetry')) text=text.replace('#!/usr/bin/env node\n','#!/usr/bin/env node\n// Explicit opt-in is required for upstream choice telemetry in this migration.\nprocess.env.IMPECCABLE_NO_TELEMETRY ??= "1";\n');
  if(text!==old) fs.writeFileSync(file,text);
}
const skill=path.join(web,'SKILL.md');
let text=fs.readFileSync(skill,'utf8');
text=text.replace(/^description:.*$/m,'description: Design, review and refine frontend interfaces, using focused playbooks for new surfaces, accessibility, typography, motion and live browser iteration.');
fs.writeFileSync(skill,text);
for(const file of walk(path.join(root,'verification'))) {
  if(!/\.(py|yaml|txt)$/.test(file))continue;
  const old=fs.readFileSync(file,'utf8');
  const text=old.replaceAll('.claude/mcp/','.codex/mcp/').replaceAll('".claude", "mcp"','".codex", "mcp"');
  if(text!==old)fs.writeFileSync(file,text);
}
// The exact fixture-only directories are mechanically renamed to native paths.
for(const dir of ['web-design-fixture','web-design-fixture-valid']) {
 const src=path.join(root,'verification/fixtures/packs',dir,'scaffold/.claude/mcp');
 const dest=path.join(root,'verification/fixtures/packs',dir,'scaffold/.codex/mcp');
 if(fs.existsSync(src)){fs.mkdirSync(path.dirname(dest),{recursive:true});fs.renameSync(src,dest);}
}
